import { pool, withTransaction } from '../database/db.js';
import { NotFoundError, ForbiddenError, ValidationError } from '../middleware/errorHandler.js';
import {
  PaymentRecord,
  PaymentEventRecord,
  InvoiceRecord,
  InvoiceDetailResponse,
  InvoiceItemDetail,
} from '../models/payment.js';
import { logger } from '../logger/index.js';

export class PaymentService {
  /**
   * Retrieves the authoritative payment record and audit timeline for an order (PAY-01, PAY-02).
   */
  async getPaymentByOrderId(
    orderId: string,
    userId: string,
    userRole: string
  ): Promise<{ payment: PaymentRecord; events: PaymentEventRecord[] }> {
    // 1. Fetch order for ownership verification
    const orderRes = await pool.query(
      `SELECT o.id, o.customer_id, o.restaurant_id, r.owner_id as restaurant_owner_id
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.id = $1`,
      [orderId]
    );

    if (orderRes.rows.length === 0) {
      throw new NotFoundError(`Order with ID ${orderId} not found`);
    }

    const order = orderRes.rows[0];

    // Authorization checks
    if (userRole === 'CUSTOMER' && order.customer_id !== userId) {
      throw new ForbiddenError('You are not authorized to view payment details for this order');
    }
    if (userRole === 'RESTAURANT_ADMIN' && order.restaurant_owner_id !== userId) {
      throw new ForbiddenError('You are not authorized to view payment details for this restaurant');
    }

    // 2. Fetch or initialize payment record (PAY-01)
    let paymentRes = await pool.query(
      `SELECT id, order_id, payment_method, payment_status, amount, currency,
              collected_at, collected_by_user_id, transaction_reference, created_at, updated_at
       FROM payments
       WHERE order_id = $1`,
      [orderId]
    );

    if (paymentRes.rows.length === 0) {
      // Auto-backfill payment record if missing from an existing order
      const fullOrder = await pool.query(
        `SELECT total_amount, payment_method, payment_status, created_at FROM orders WHERE id = $1`,
        [orderId]
      );
      const inserted = await pool.query(
        `INSERT INTO payments (order_id, payment_method, payment_status, amount, currency, created_at, updated_at)
         VALUES ($1, $2, $3, $4, 'INR', $5, $5)
         RETURNING id, order_id, payment_method, payment_status, amount, currency,
                   collected_at, collected_by_user_id, transaction_reference, created_at, updated_at`,
        [
          orderId,
          fullOrder.rows[0].payment_method || 'CASH_ON_DELIVERY',
          fullOrder.rows[0].payment_status || 'PENDING',
          fullOrder.rows[0].total_amount,
          fullOrder.rows[0].created_at,
        ]
      );
      paymentRes = inserted;
    }

    const paymentRow = paymentRes.rows[0];
    const payment: PaymentRecord = {
      id: paymentRow.id,
      orderId: paymentRow.order_id,
      paymentMethod: paymentRow.payment_method,
      paymentStatus: paymentRow.payment_status,
      amount: paymentRow.amount,
      currency: paymentRow.currency,
      collectedAt: paymentRow.collected_at ? new Date(paymentRow.collected_at) : null,
      collectedByUserId: paymentRow.collected_by_user_id,
      transactionReference: paymentRow.transaction_reference,
      createdAt: new Date(paymentRow.created_at),
      updatedAt: new Date(paymentRow.updated_at),
    };

    // 3. Fetch audit events
    const eventsRes = await pool.query(
      `SELECT id, payment_id, from_status, to_status, actor_user_id, actor_role,
              transaction_reference, note, created_at
       FROM payment_events
       WHERE payment_id = $1
       ORDER BY created_at ASC`,
      [payment.id]
    );

    const events: PaymentEventRecord[] = eventsRes.rows.map((r) => ({
      id: r.id,
      paymentId: r.payment_id,
      fromStatus: r.from_status,
      toStatus: r.to_status,
      actorUserId: r.actor_user_id,
      actorRole: r.actor_role,
      transactionReference: r.transaction_reference,
      note: r.note,
      createdAt: new Date(r.created_at),
    }));

    return { payment, events };
  }

  /**
   * Records payment collection by authorized delivery partner or admin (PAY-02, PAY-03, PAY-05).
   * Enforces backend permissions, idempotency, and audit trail.
   */
  async recordCollection(
    orderId: string,
    actorId: string,
    actorRole: string,
    input: { transactionReference?: string; note?: string } = {}
  ): Promise<{ payment: PaymentRecord; isAlreadyCollected: boolean }> {
    // 1. Permission Check (PAY-03): Customers cannot mark their own payments collected
    if (actorRole === 'CUSTOMER') {
      throw new ForbiddenError('Customers cannot mark their own orders as collected');
    }

    if (
      actorRole !== 'DELIVERY_PARTNER' &&
      actorRole !== 'RESTAURANT_ADMIN' &&
      actorRole !== 'SYSTEM_ADMIN'
    ) {
      throw new ForbiddenError('Action requires DELIVERY_PARTNER, RESTAURANT_ADMIN, or SYSTEM_ADMIN role');
    }

    return await withTransaction(async (client) => {
      // 2. Fetch order and lock payment record
      const orderRes = await client.query(
        `SELECT o.id, o.fulfillment_status, o.payment_status, o.total_amount, o.restaurant_id,
                r.owner_id as restaurant_owner_id
         FROM orders o
         JOIN restaurants r ON o.restaurant_id = r.id
         WHERE o.id = $1
         FOR UPDATE`,
        [orderId]
      );

      if (orderRes.rows.length === 0) {
        throw new NotFoundError(`Order with ID ${orderId} not found`);
      }

      const order = orderRes.rows[0];

      if (actorRole === 'RESTAURANT_ADMIN' && order.restaurant_owner_id !== actorId) {
        throw new ForbiddenError('You are not authorized to collect payment for this restaurant');
      }

      // Check order fulfillment lifecycle
      if (order.fulfillment_status === 'CANCELLED') {
        throw new ValidationError('Cannot collect payment for a cancelled order');
      }

      // 3. Check existing payment record
      const paymentRes = await client.query(
        `SELECT id, order_id, payment_method, payment_status, amount, currency,
                collected_at, collected_by_user_id, transaction_reference, created_at, updated_at
         FROM payments
         WHERE order_id = $1
         FOR UPDATE`,
        [orderId]
      );

      let paymentRow = paymentRes.rows[0];

      // If no payment row exists, initialize it first
      if (!paymentRow) {
        const initRes = await client.query(
          `INSERT INTO payments (order_id, payment_method, payment_status, amount, currency)
           VALUES ($1, 'CASH_ON_DELIVERY', 'PENDING', $2, 'INR')
           RETURNING *`,
          [orderId, order.total_amount]
        );
        paymentRow = initRes.rows[0];
      }

      // 4. Idempotency Check (PAY-05): If already collected, return cleanly without duplicate event
      if (paymentRow.payment_status === 'PAID') {
        logger.info(`Payment for order ${orderId} is already marked as PAID. Returning existing record.`);
        return {
          payment: {
            id: paymentRow.id,
            orderId: paymentRow.order_id,
            paymentMethod: paymentRow.payment_method,
            paymentStatus: paymentRow.payment_status,
            amount: paymentRow.amount,
            currency: paymentRow.currency,
            collectedAt: paymentRow.collected_at ? new Date(paymentRow.collected_at) : null,
            collectedByUserId: paymentRow.collected_by_user_id,
            transactionReference: paymentRow.transaction_reference,
            createdAt: new Date(paymentRow.created_at),
            updatedAt: new Date(paymentRow.updated_at),
          },
          isAlreadyCollected: true,
        };
      }

      const now = new Date();
      const reference = input.transactionReference?.trim() || `COD-${Date.now()}`;
      const note = input.note?.trim() || 'Cash on Delivery collected upon handover';

      // 5. Update payments table
      const updatedPaymentRes = await client.query(
        `UPDATE payments
         SET payment_status = 'PAID',
             collected_at = $1,
             collected_by_user_id = $2,
             transaction_reference = $3,
             updated_at = $1
         WHERE id = $4
         RETURNING *`,
        [now, actorId, reference, paymentRow.id]
      );

      // 6. Update orders table payment_status
      await client.query(
        `UPDATE orders
         SET payment_status = 'PAID',
             updated_at = $1
         WHERE id = $2`,
        [now, orderId]
      );

      // 7. Insert audit event into payment_events (NFR-16)
      await client.query(
        `INSERT INTO payment_events (
           payment_id, from_status, to_status, actor_user_id, actor_role, transaction_reference, note, created_at
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          paymentRow.id,
          paymentRow.payment_status,
          'PAID',
          actorId,
          actorRole,
          reference,
          note,
          now,
        ]
      );

      const updated = updatedPaymentRes.rows[0];

      return {
        payment: {
          id: updated.id,
          orderId: updated.order_id,
          paymentMethod: updated.payment_method,
          paymentStatus: updated.payment_status,
          amount: updated.amount,
          currency: updated.currency,
          collectedAt: new Date(updated.collected_at),
          collectedByUserId: updated.collected_by_user_id,
          transactionReference: updated.transaction_reference,
          createdAt: new Date(updated.created_at),
          updatedAt: new Date(updated.updated_at),
        },
        isAlreadyCollected: false,
      };
    });
  }

  /**
   * Generates or retrieves an immutable tax invoice for an order (PAY-04, PAY-05).
   * Guaranteed to be idempotent and consistent with order snapshots.
   */
  async getOrCreateInvoice(
    orderId: string,
    userId: string,
    userRole: string
  ): Promise<InvoiceDetailResponse> {
    // 1. Fetch order details with restaurant metadata
    const orderRes = await pool.query(
      `SELECT o.id, o.public_order_number, o.customer_id, o.restaurant_id,
              o.delivery_address_snapshot, o.customer_phone_snapshot, o.customer_name_snapshot,
              o.subtotal, o.delivery_fee, o.tax_amount, o.discount_amount, o.total_amount,
              o.fulfillment_status, o.payment_status, o.payment_method, o.created_at,
              r.name as restaurant_name, r.address as restaurant_address, r.phone as restaurant_phone,
              r.cuisine_type, r.food_license_number, r.owner_id as restaurant_owner_id
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.id = $1`,
      [orderId]
    );

    if (orderRes.rows.length === 0) {
      throw new NotFoundError(`Order with ID ${orderId} not found`);
    }

    const order = orderRes.rows[0];

    // Authorization check
    if (userRole === 'CUSTOMER' && order.customer_id !== userId) {
      throw new ForbiddenError('You are not authorized to view the invoice for this order');
    }
    if (userRole === 'RESTAURANT_ADMIN' && order.restaurant_owner_id !== userId) {
      throw new ForbiddenError('You are not authorized to view the invoice for this restaurant');
    }

    // 2. Fetch existing invoice or create one atomically (idempotency, PAY-05)
    let invoiceRow = await this.findInvoiceByOrderId(orderId);

    if (!invoiceRow) {
      invoiceRow = await withTransaction(async (client) => {
        // Double check inside transaction
        const existing = await client.query(
          `SELECT * FROM invoices WHERE order_id = $1 FOR UPDATE`,
          [orderId]
        );
        if (existing.rows.length > 0) {
          return existing.rows[0];
        }

        // Generate sequential invoice number: INV-YYYY-XXXXXX
        const year = new Date().getFullYear();
        const countRes = await client.query(`SELECT count(*) FROM invoices`);
        const nextNum = String(parseInt(countRes.rows[0].count, 10) + 1).padStart(6, '0');
        const invoiceNumber = `INV-${year}-${nextNum}`;

        const insertRes = await client.query(
          `INSERT INTO invoices (
             order_id, invoice_number, customer_id, restaurant_id, issued_at,
             subtotal, delivery_fee, tax_amount, discount_amount, total_amount, currency,
             payment_method, payment_status, recipient_name, recipient_phone, delivery_address
           ) VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, $5, $6, $7, $8, $9, 'INR', $10, $11, $12, $13, $14)
           RETURNING *`,
          [
            orderId,
            invoiceNumber,
            order.customer_id,
            order.restaurant_id,
            order.subtotal,
            order.delivery_fee,
            order.tax_amount,
            order.discount_amount,
            order.total_amount,
            order.payment_method,
            order.payment_status,
            order.customer_name_snapshot,
            order.customer_phone_snapshot,
            order.delivery_address_snapshot,
          ]
        );

        return insertRes.rows[0];
      });
    }

    // 3. Fetch snapshot line items
    const itemsRes = await pool.query(
      `SELECT id, item_name_snapshot, item_description_snapshot, unit_price_snapshot,
              is_veg_snapshot, quantity, line_total, item_instructions
       FROM order_items
       WHERE order_id = $1
       ORDER BY created_at ASC`,
      [orderId]
    );

    const items: InvoiceItemDetail[] = itemsRes.rows.map((r) => ({
      id: r.id,
      name: r.item_name_snapshot,
      description: r.item_description_snapshot,
      unitPrice: r.unit_price_snapshot,
      isVeg: r.is_veg_snapshot,
      quantity: r.quantity,
      lineTotal: r.line_total,
      itemInstructions: r.item_instructions,
    }));

    // 4. Fetch latest payment collection state
    const paymentRes = await pool.query(
      `SELECT payment_method, payment_status, collected_at, transaction_reference
       FROM payments
       WHERE order_id = $1`,
      [orderId]
    );
    const pRow = paymentRes.rows[0];

    const invoice: InvoiceRecord = {
      id: invoiceRow.id,
      orderId: invoiceRow.order_id,
      invoiceNumber: invoiceRow.invoice_number,
      customerId: invoiceRow.customer_id,
      restaurantId: invoiceRow.restaurant_id,
      issuedAt: new Date(invoiceRow.issued_at),
      subtotal: invoiceRow.subtotal,
      deliveryFee: invoiceRow.delivery_fee,
      taxAmount: invoiceRow.tax_amount,
      discountAmount: invoiceRow.discount_amount,
      totalAmount: invoiceRow.total_amount,
      currency: invoiceRow.currency,
      paymentMethod: invoiceRow.payment_method,
      paymentStatus: invoiceRow.payment_status,
      recipientName: invoiceRow.recipient_name,
      recipientPhone: invoiceRow.recipient_phone,
      deliveryAddress: invoiceRow.delivery_address,
      createdAt: new Date(invoiceRow.created_at),
      updatedAt: new Date(invoiceRow.updated_at),
    };

    return {
      invoice,
      order: {
        id: order.id,
        publicOrderNumber: order.public_order_number,
        createdAt: new Date(order.created_at),
        fulfillmentStatus: order.fulfillment_status,
      },
      restaurant: {
        id: order.restaurant_id,
        name: order.restaurant_name,
        address: order.restaurant_address,
        phone: order.restaurant_phone,
        cuisineType: order.cuisine_type,
        foodLicenseNumber: order.food_license_number,
      },
      customer: {
        name: order.customer_name_snapshot,
        phone: order.customer_phone_snapshot,
        deliveryAddress: order.delivery_address_snapshot,
      },
      items,
      breakdown: {
        subtotal: invoice.subtotal,
        deliveryFee: invoice.deliveryFee,
        taxAmount: invoice.taxAmount,
        discountAmount: invoice.discountAmount,
        totalAmount: invoice.totalAmount,
        currency: invoice.currency,
      },
      payment: {
        method: pRow?.payment_method || invoice.paymentMethod,
        status: pRow?.payment_status || invoice.paymentStatus,
        collectedAt: pRow?.collected_at ? new Date(pRow.collected_at) : null,
        transactionReference: pRow?.transaction_reference || null,
      },
    };
  }

  /**
   * Generates a clean, print-friendly HTML document for the invoice (Theme & UI spec).
   */
  generateInvoiceHtml(detail: InvoiceDetailResponse): string {
    const { invoice, order, restaurant, customer, items, breakdown, payment } = detail;
    const dateFormatted = new Date(invoice.issuedAt).toLocaleDateString('en-IN', {
      timeZone: 'Asia/Kolkata',
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const rowsHtml = items
      .map(
        (i) => `
      <tr>
        <td style="padding: 10px; border-bottom: 1px solid #eee;">
          <strong>${i.isVeg ? '<span style="color:#10B981">●</span>' : '<span style="color:#EF4444">▲</span>'} ${i.name}</strong>
          ${i.description ? `<br><small style="color: #666;">${i.description}</small>` : ''}
        </td>
        <td style="padding: 10px; text-align: center; border-bottom: 1px solid #eee;">${i.quantity}</td>
        <td style="padding: 10px; text-align: right; border-bottom: 1px solid #eee;">₹${parseFloat(i.unitPrice).toFixed(2)}</td>
        <td style="padding: 10px; text-align: right; border-bottom: 1px solid #eee;">₹${parseFloat(i.lineTotal).toFixed(2)}</td>
      </tr>`
      )
      .join('');

    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Tax Invoice - ${invoice.invoiceNumber}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 24px; color: #1f2937; line-height: 1.5; }
    .invoice-card { max-width: 800px; margin: 0 auto; background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
    .header { display: flex; justify-content: space-between; border-bottom: 2px solid #ff5722; padding-bottom: 16px; margin-bottom: 24px; }
    .brand { font-size: 26px; font-weight: 800; color: #ff5722; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; background: ${payment.status === 'PAID' ? '#d1fae5; color: #065f46;' : '#fee2e2; color: #991b1b;'} }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th { background: #f9fafb; text-align: left; padding: 10px; font-size: 13px; text-transform: uppercase; color: #6b7280; border-bottom: 1px solid #e5e7eb; }
    .total-row { display: flex; justify-content: flex-end; margin-top: 24px; }
    .total-box { width: 280px; }
    .total-line { display: flex; justify-content: space-between; padding: 6px 0; }
    .grand-total { font-size: 18px; font-weight: 700; color: #ff5722; border-top: 2px solid #e5e7eb; padding-top: 8px; margin-top: 8px; }
    @media print { body { padding: 0; } .invoice-card { border: none; box-shadow: none; } .no-print { display: none; } }
  </style>
</head>
<body>
  <div class="invoice-card">
    <div class="header">
      <div>
        <div class="brand">EatFirm</div>
        <div style="font-size: 13px; color: #6b7280;">Official Food Delivery Tax Invoice</div>
      </div>
      <div style="text-align: right;">
        <h2 style="margin: 0; color: #111;">INVOICE</h2>
        <div style="font-size: 14px; font-weight: 600;">#${invoice.invoiceNumber}</div>
        <div style="font-size: 12px; color: #6b7280;">Date: ${dateFormatted}</div>
      </div>
    </div>

    <div style="display: flex; justify-content: space-between; margin-bottom: 24px;">
      <div style="width: 48%;">
        <div style="font-size: 12px; text-transform: uppercase; color: #6b7280; font-weight: 700;">Fulfilled By:</div>
        <strong>${restaurant.name}</strong><br>
        <span style="font-size: 13px; color: #4b5563;">${restaurant.address}</span><br>
        <span style="font-size: 13px; color: #4b5563;">Phone: ${restaurant.phone}</span><br>
        <span style="font-size: 12px; color: #6b7280;">FSSAI Lic: ${restaurant.foodLicenseNumber}</span>
      </div>
      <div style="width: 48%;">
        <div style="font-size: 12px; text-transform: uppercase; color: #6b7280; font-weight: 700;">Delivered To:</div>
        <strong>${customer.name}</strong><br>
        <span style="font-size: 13px; color: #4b5563;">${customer.deliveryAddress}</span><br>
        <span style="font-size: 13px; color: #4b5563;">Phone: ${customer.phone}</span><br>
        <span style="font-size: 12px; color: #6b7280;">Order No: #${order.publicOrderNumber}</span>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Dish / Item</th>
          <th style="text-align: center;">Qty</th>
          <th style="text-align: right;">Unit Price</th>
          <th style="text-align: right;">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml}
      </tbody>
    </table>

    <div class="total-row">
      <div class="total-box">
        <div class="total-line"><span>Subtotal:</span><span>₹${parseFloat(breakdown.subtotal).toFixed(2)}</span></div>
        <div class="total-line"><span>Delivery Fee:</span><span>₹${parseFloat(breakdown.deliveryFee).toFixed(2)}</span></div>
        <div class="total-line"><span>Taxes & GST (5%):</span><span>₹${parseFloat(breakdown.taxAmount).toFixed(2)}</span></div>
        ${parseFloat(breakdown.discountAmount) > 0 ? `<div class="total-line" style="color: #10B981;"><span>Discount:</span><span>-₹${parseFloat(breakdown.discountAmount).toFixed(2)}</span></div>` : ''}
        <div class="total-line grand-total"><span>Total Payable:</span><span>₹${parseFloat(breakdown.totalAmount).toFixed(2)}</span></div>
        <div style="margin-top: 12px; text-align: right;">
          <span class="badge">${payment.status === 'PAID' ? 'PAID via ' + payment.method : 'PAYMENT DUE (' + payment.method + ')'}</span>
        </div>
      </div>
    </div>

    <div style="margin-top: 36px; padding-top: 16px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #9ca3af; text-align: center;">
      This is a system-generated electronic tax invoice authorized under Section 31 of CGST Act. Thank you for dining with EatFirm!
    </div>
  </div>
</body>
</html>`;
  }

  private async findInvoiceByOrderId(orderId: string): Promise<any> {
    const res = await pool.query(
      `SELECT * FROM invoices WHERE order_id = $1`,
      [orderId]
    );
    return res.rows[0] || null;
  }
}

export const paymentService = new PaymentService();


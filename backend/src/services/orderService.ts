import { pool } from '../database/db.js';
import {
  ValidationError,
  NotFoundError,
  ForbiddenError,
  ConflictError,
  AppError,
} from '../middleware/errorHandler.js';
import {
  OrderModel,
  OrderItemModel,
  OrderStatusEventModel,
  OrderFulfillmentStatus,
  CreateOrderInput,
  CancelOrderInput,
} from '../models/order.js';
import { toPaise, fromPaise } from '../utils/money.js';
import { logAuditEvent } from './auditService.js';

export class OrderService {
  /**
   * Generates a unique, friendly public order number formatted as ORD-YYYYMMDD-XXXXX
   */
  private static generateOrderNumber(): string {
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    const randomHex = Math.floor(10000 + Math.random() * 90000);
    return `ORD-${yyyy}${mm}${dd}-${randomHex}`;
  }

  /**
   * Places an order from the user's active cart.
   * Performs server-authoritative money recalculation (NFR-13) and enforces idempotency (ORD-04).
   */
  static async createOrderFromCart(
    userId: string,
    input: CreateOrderInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<{ order: OrderModel; isExisting: boolean }> {
    const {
      deliveryAddress,
      customerPhone,
      customerName,
      specialInstructions,
      isScheduled,
      scheduledFor,
      idempotencyKey,
      paymentMethod = 'CASH_ON_DELIVERY',
    } = input;

    if (!deliveryAddress || deliveryAddress.trim().length < 5) {
      throw new ValidationError('A valid delivery address is required (minimum 5 characters)');
    }
    if (!customerPhone || customerPhone.trim().length < 10) {
      throw new ValidationError('A valid 10-digit contact phone number is required');
    }
    if (!customerName || customerName.trim().length < 2) {
      throw new ValidationError('A valid customer name is required');
    }
    if (!idempotencyKey || idempotencyKey.trim().length === 0) {
      throw new ValidationError('Idempotency key is required for order placement');
    }

    // 1. Idempotency Check (ORD-04)
    const existingOrderRes = await pool.query(
      `SELECT id FROM orders WHERE idempotency_key = $1 AND customer_id = $2`,
      [idempotencyKey, userId]
    );

    if (existingOrderRes.rows.length > 0) {
      const existing = await this.getOrderById(userId, 'CUSTOMER', existingOrderRes.rows[0].id);
      return { order: existing, isExisting: true };
    }

    const client = await pool.connect();
    let orderId: string;

    try {
      await client.query('BEGIN');

      // 2. Fetch and lock customer's active cart
      const cartRes = await client.query(
        `SELECT c.id, c.customer_id, c.restaurant_id, c.special_instructions,
                r.name as restaurant_name, r.is_open, r.approval_status
         FROM carts c
         JOIN restaurants r ON c.restaurant_id = r.id
         WHERE c.customer_id = $1
         FOR UPDATE`,
        [userId]
      );

      if (cartRes.rows.length === 0) {
        throw new ValidationError('Your cart is empty. Please add items before placing an order.');
      }

      const cartRow = cartRes.rows[0];

      if (cartRow.approval_status !== 'APPROVED') {
        throw new ValidationError('Restaurant is currently not approved to accept orders');
      }

      // 3. Fetch cart items joined with live menu item data
      const itemsRes = await client.query(
        `SELECT ci.id as cart_item_id, ci.menu_item_id, ci.quantity, ci.item_instructions,
                m.name, m.description, m.price, m.is_veg, m.is_available,
                m.is_special_offer, m.offer_price
         FROM cart_items ci
         JOIN menu_items m ON ci.menu_item_id = m.id
         WHERE ci.cart_id = $1`,
        [cartRow.id]
      );

      if (itemsRes.rows.length === 0) {
        throw new ValidationError('Your cart contains no items.');
      }

      // 4. Validate live availability and calculate authoritative prices
      let subtotalPaise = 0;
      const orderItemsToInsert: {
        menuItemId: string;
        name: string;
        description: string | null;
        unitPrice: string;
        isVeg: boolean;
        quantity: number;
        lineTotal: string;
        itemInstructions: string | null;
      }[] = [];

      for (const item of itemsRes.rows) {
        if (!item.is_available) {
          throw new ValidationError(`"${item.name}" is no longer available. Please update your cart.`);
        }

        const isOffer = item.is_special_offer && item.offer_price !== null;
        const unitPriceStr = isOffer ? item.offer_price : item.price;
        const unitPricePaise = toPaise(unitPriceStr);
        const lineTotalPaise = unitPricePaise * item.quantity;
        subtotalPaise += lineTotalPaise;

        orderItemsToInsert.push({
          menuItemId: item.menu_item_id,
          name: item.name,
          description: item.description,
          unitPrice: unitPriceStr,
          isVeg: item.is_veg,
          quantity: item.quantity,
          lineTotal: fromPaise(lineTotalPaise),
          itemInstructions: item.item_instructions,
        });
      }

      const deliveryFeePaise = subtotalPaise >= 50000 ? 0 : 3000;
      const taxPaise = Math.round(subtotalPaise * 0.05);
      const discountPaise = 0;
      const totalPaise = subtotalPaise + deliveryFeePaise + taxPaise - discountPaise;

      const subtotalStr = fromPaise(subtotalPaise);
      const deliveryFeeStr = fromPaise(deliveryFeePaise);
      const taxAmountStr = fromPaise(taxPaise);
      const discountAmountStr = fromPaise(discountPaise);
      const totalAmountStr = fromPaise(totalPaise);

      // 5. Generate Order and Public Order Number
      const publicOrderNumber = this.generateOrderNumber();
      const orderInstructions = specialInstructions ?? cartRow.special_instructions;

      const orderInsertRes = await client.query(
        `INSERT INTO orders (
          public_order_number, customer_id, restaurant_id,
          delivery_address_snapshot, customer_phone_snapshot, customer_name_snapshot,
          special_instructions, is_scheduled, scheduled_for,
          subtotal, delivery_fee, tax_amount, discount_amount, total_amount,
          fulfillment_status, payment_status, payment_method, idempotency_key
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18
        ) RETURNING id`,
        [
          publicOrderNumber,
          userId,
          cartRow.restaurant_id,
          deliveryAddress.trim(),
          customerPhone.trim(),
          customerName.trim(),
          orderInstructions,
          isScheduled ?? false,
          scheduledFor ? new Date(scheduledFor) : null,
          subtotalStr,
          deliveryFeeStr,
          taxAmountStr,
          discountAmountStr,
          totalAmountStr,
          'PLACED',
          'PENDING',
          paymentMethod,
          idempotencyKey,
        ]
      );

      orderId = orderInsertRes.rows[0].id;

      // 6. Insert Order Items snapshots
      for (const item of orderItemsToInsert) {
        await client.query(
          `INSERT INTO order_items (
            order_id, menu_item_id, item_name_snapshot, item_description_snapshot,
            unit_price_snapshot, is_veg_snapshot, quantity, line_total, item_instructions
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            orderId,
            item.menuItemId,
            item.name,
            item.description,
            item.unitPrice,
            item.isVeg,
            item.quantity,
            item.lineTotal,
            item.itemInstructions,
          ]
        );
      }

      // 7. Insert Initial Status Event
      await client.query(
        `INSERT INTO order_status_events (
          order_id, from_status, to_status, actor_user_id, actor_role, note
        ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          orderId,
          null,
          'PLACED',
          userId,
          'CUSTOMER',
          'Order placed successfully with Cash On Delivery',
        ]
      );

      // 8. Clear the active cart
      await client.query(`DELETE FROM carts WHERE id = $1`, [cartRow.id]);

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    await logAuditEvent({
      action: 'ORDER_PLACED',
      actorId: userId,
      actorRole: 'CUSTOMER',
      ipAddress,
      userAgent,
      details: { orderId, idempotencyKey },
    });

    const order = await this.getOrderById(userId, 'CUSTOMER', orderId);
    return { order, isExisting: false };
  }

  /**
   * Retrieves single order by ID with ownership check, snapshots, and timeline.
   */
  static async getOrderById(
    userId: string,
    userRole: string,
    orderId: string
  ): Promise<OrderModel> {
    const orderRes = await pool.query(
      `SELECT o.*, r.name as restaurant_name, r.address as restaurant_address, r.owner_id as restaurant_owner_id
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       WHERE o.id = $1`,
      [orderId]
    );

    if (orderRes.rows.length === 0) {
      throw new NotFoundError('Order not found');
    }

    const orderRow = orderRes.rows[0];

    // Ownership check
    if (userRole === 'CUSTOMER' && orderRow.customer_id !== userId) {
      throw new ForbiddenError('You are not authorized to view this order');
    }
    if (userRole === 'RESTAURANT_ADMIN' && orderRow.restaurant_owner_id !== userId) {
      throw new ForbiddenError('You do not own the restaurant for this order');
    }

    // Line items
    const itemsRes = await pool.query(
      `SELECT * FROM order_items WHERE order_id = $1 ORDER BY created_at ASC`,
      [orderId]
    );

    const items: OrderItemModel[] = itemsRes.rows.map((row) => ({
      id: row.id,
      orderId: row.order_id,
      menuItemId: row.menu_item_id,
      itemName: row.item_name_snapshot,
      itemDescription: row.item_description_snapshot,
      unitPrice: row.unit_price_snapshot,
      isVeg: row.is_veg_snapshot,
      quantity: row.quantity,
      lineTotal: row.line_total,
      itemInstructions: row.item_instructions,
      createdAt: row.created_at.toISOString(),
    }));

    // Status Timeline
    const timelineRes = await pool.query(
      `SELECT * FROM order_status_events WHERE order_id = $1 ORDER BY created_at ASC`,
      [orderId]
    );

    const statusTimeline: OrderStatusEventModel[] = timelineRes.rows.map((row) => ({
      id: row.id,
      orderId: row.order_id,
      fromStatus: row.from_status,
      toStatus: row.to_status,
      actorUserId: row.actor_user_id,
      actorRole: row.actor_role,
      note: row.note,
      createdAt: row.created_at.toISOString(),
    }));

    return {
      id: orderRow.id,
      publicOrderNumber: orderRow.public_order_number,
      customerId: orderRow.customer_id,
      restaurantId: orderRow.restaurant_id,
      restaurantName: orderRow.restaurant_name,
      restaurantAddress: orderRow.restaurant_address,
      deliveryAddressSnapshot: orderRow.delivery_address_snapshot,
      customerPhoneSnapshot: orderRow.customer_phone_snapshot,
      customerNameSnapshot: orderRow.customer_name_snapshot,
      specialInstructions: orderRow.special_instructions,
      isScheduled: orderRow.is_scheduled,
      scheduledFor: orderRow.scheduled_for ? orderRow.scheduled_for.toISOString() : null,
      subtotal: orderRow.subtotal,
      deliveryFee: orderRow.delivery_fee,
      taxAmount: orderRow.tax_amount,
      discountAmount: orderRow.discount_amount,
      totalAmount: orderRow.total_amount,
      fulfillmentStatus: orderRow.fulfillment_status,
      paymentStatus: orderRow.payment_status,
      paymentMethod: orderRow.payment_method,
      idempotencyKey: orderRow.idempotency_key,
      cancellationReason: orderRow.cancellation_reason,
      cancelledAt: orderRow.cancelled_at ? orderRow.cancelled_at.toISOString() : null,
      items,
      statusTimeline,
      createdAt: orderRow.created_at.toISOString(),
      updatedAt: orderRow.updated_at.toISOString(),
    };
  }

  /**
   * Lists orders for the current user based on role (Customer sees their own; Restaurant Admin sees their restaurant's).
   */
  static async listOrders(
    userId: string,
    userRole: string,
    options: { status?: string; limit?: number; offset?: number } = {}
  ): Promise<{ orders: OrderModel[]; total: number }> {
    const limit = Math.min(50, Math.max(1, options.limit ?? 20));
    const offset = Math.max(0, options.offset ?? 0);

    let whereClause = '';
    const params: unknown[] = [];

    if (userRole === 'CUSTOMER') {
      params.push(userId);
      whereClause = `WHERE o.customer_id = $${params.length}`;
    } else if (userRole === 'RESTAURANT_ADMIN') {
      params.push(userId);
      whereClause = `WHERE r.owner_id = $${params.length}`;
    } else if (userRole === 'SYSTEM_ADMIN') {
      whereClause = `WHERE 1=1`;
    } else {
      throw new ForbiddenError('Unauthorized role for listing orders');
    }

    if (options.status) {
      params.push(options.status);
      whereClause += ` AND o.fulfillment_status = $${params.length}`;
    }

    const countRes = await pool.query(
      `SELECT COUNT(*) as total
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       ${whereClause}`,
      params
    );
    const total = parseInt(countRes.rows[0].total, 10);

    const listParams = [...params, limit, offset];
    const ordersRes = await pool.query(
      `SELECT o.*, r.name as restaurant_name, r.address as restaurant_address
       FROM orders o
       JOIN restaurants r ON o.restaurant_id = r.id
       ${whereClause}
       ORDER BY o.created_at DESC
       LIMIT $${listParams.length - 1} OFFSET $${listParams.length}`,
      listParams
    );

    const orders: OrderModel[] = [];
    for (const orderRow of ordersRes.rows) {
      const itemsRes = await pool.query(
        `SELECT * FROM order_items WHERE order_id = $1 ORDER BY created_at ASC`,
        [orderRow.id]
      );
      const items: OrderItemModel[] = itemsRes.rows.map((row) => ({
        id: row.id,
        orderId: row.order_id,
        menuItemId: row.menu_item_id,
        itemName: row.item_name_snapshot,
        itemDescription: row.item_description_snapshot,
        unitPrice: row.unit_price_snapshot,
        isVeg: row.is_veg_snapshot,
        quantity: row.quantity,
        lineTotal: row.line_total,
        itemInstructions: row.item_instructions,
        createdAt: row.created_at.toISOString(),
      }));

      orders.push({
        id: orderRow.id,
        publicOrderNumber: orderRow.public_order_number,
        customerId: orderRow.customer_id,
        restaurantId: orderRow.restaurant_id,
        restaurantName: orderRow.restaurant_name,
        restaurantAddress: orderRow.restaurant_address,
        deliveryAddressSnapshot: orderRow.delivery_address_snapshot,
        customerPhoneSnapshot: orderRow.customer_phone_snapshot,
        customerNameSnapshot: orderRow.customer_name_snapshot,
        specialInstructions: orderRow.special_instructions,
        isScheduled: orderRow.is_scheduled,
        scheduledFor: orderRow.scheduled_for ? orderRow.scheduled_for.toISOString() : null,
        subtotal: orderRow.subtotal,
        deliveryFee: orderRow.delivery_fee,
        taxAmount: orderRow.tax_amount,
        discountAmount: orderRow.discount_amount,
        totalAmount: orderRow.total_amount,
        fulfillmentStatus: orderRow.fulfillment_status,
        paymentStatus: orderRow.payment_status,
        paymentMethod: orderRow.payment_method,
        idempotencyKey: orderRow.idempotency_key,
        cancellationReason: orderRow.cancellation_reason,
        cancelledAt: orderRow.cancelled_at ? orderRow.cancelled_at.toISOString() : null,
        items,
        createdAt: orderRow.created_at.toISOString(),
        updatedAt: orderRow.updated_at.toISOString(),
      });
    }

    return { orders, total };
  }

  /**
   * Cancels an order with status eligibility check (SRS ORD-08, Section 6, NFR-14, NFR-16).
   * Eligible states: PLACED, CONFIRMED.
   * Orders are NEVER deleted from database (SRS Section 6).
   */
  static async cancelOrder(
    userId: string,
    userRole: string,
    orderId: string,
    input: CancelOrderInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<OrderModel> {
    const { reason } = input;
    if (!reason || reason.trim().length < 3) {
      throw new ValidationError('A cancellation reason is required (minimum 3 characters)');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const orderRes = await client.query(
        `SELECT o.*, r.owner_id as restaurant_owner_id
         FROM orders o
         JOIN restaurants r ON o.restaurant_id = r.id
         WHERE o.id = $1
         FOR UPDATE`,
        [orderId]
      );

      if (orderRes.rows.length === 0) {
        throw new NotFoundError('Order not found');
      }

      const order = orderRes.rows[0];

      // Ownership check
      if (userRole === 'CUSTOMER' && order.customer_id !== userId) {
        throw new ForbiddenError('You can only cancel your own orders');
      }
      if (userRole === 'RESTAURANT_ADMIN' && order.restaurant_owner_id !== userId) {
        throw new ForbiddenError('You can only cancel orders for your restaurant');
      }

      // Status eligibility check
      if (order.fulfillment_status === 'CANCELLED') {
        throw new ConflictError('Order is already cancelled');
      }
      if (order.fulfillment_status === 'DELIVERED') {
        throw new ConflictError('Completed orders cannot be cancelled');
      }
      if (userRole === 'CUSTOMER' && order.fulfillment_status !== 'PLACED' && order.fulfillment_status !== 'CONFIRMED') {
        throw new ConflictError(
          `Cannot cancel order in "${order.fulfillment_status}" status. The kitchen has already started preparing your food.`
        );
      }

      const prevStatus = order.fulfillment_status;

      await client.query(
        `UPDATE orders
         SET fulfillment_status = 'CANCELLED',
             cancellation_reason = $1,
             cancelled_at = CURRENT_TIMESTAMP,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [reason.trim(), orderId]
      );

      await client.query(
        `INSERT INTO order_status_events (
          order_id, from_status, to_status, actor_user_id, actor_role, note
        ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          orderId,
          prevStatus,
          'CANCELLED',
          userId,
          userRole,
          `Cancelled: ${reason.trim()}`,
        ]
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    await logAuditEvent({
      action: 'ORDER_CANCELLED',
      actorId: userId,
      actorRole: userRole,
      ipAddress,
      userAgent,
      details: { orderId, reason },
    });

    return this.getOrderById(userId, userRole, orderId);
  }

  /**
   * Updates fulfillment status (for restaurant admin / system admin lifecycle management).
   */
  static async updateFulfillmentStatus(
    userId: string,
    userRole: string,
    orderId: string,
    newStatus: OrderFulfillmentStatus,
    note?: string
  ): Promise<OrderModel> {
    const validTransitions: Record<OrderFulfillmentStatus, OrderFulfillmentStatus[]> = {
      PLACED: ['CONFIRMED', 'CANCELLED'],
      CONFIRMED: ['PREPARING', 'CANCELLED'],
      PREPARING: ['OUT_FOR_DELIVERY', 'CANCELLED'],
      OUT_FOR_DELIVERY: ['DELIVERED'],
      DELIVERED: [],
      CANCELLED: [],
    };

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const orderRes = await client.query(
        `SELECT o.*, r.owner_id as restaurant_owner_id
         FROM orders o
         JOIN restaurants r ON o.restaurant_id = r.id
         WHERE o.id = $1
         FOR UPDATE`,
        [orderId]
      );

      if (orderRes.rows.length === 0) {
        throw new NotFoundError('Order not found');
      }

      const order = orderRes.rows[0];

      if (userRole === 'RESTAURANT_ADMIN' && order.restaurant_owner_id !== userId) {
        throw new ForbiddenError('You can only update orders for your restaurant');
      }

      const allowedNext = validTransitions[order.fulfillment_status as OrderFulfillmentStatus] || [];
      if (!allowedNext.includes(newStatus)) {
        throw new ValidationError(
          `Invalid status transition from "${order.fulfillment_status}" to "${newStatus}"`
        );
      }

      await client.query(
        `UPDATE orders
         SET fulfillment_status = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [newStatus, orderId]
      );

      await client.query(
        `INSERT INTO order_status_events (
          order_id, from_status, to_status, actor_user_id, actor_role, note
        ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [orderId, order.fulfillment_status, newStatus, userId, userRole, note ?? null]
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    return this.getOrderById(userId, userRole, orderId);
  }
}

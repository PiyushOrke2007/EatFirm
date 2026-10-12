import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/database/db.js';
import { CashOnDeliveryAdapter, MockOnlinePaymentGatewayAdapter } from '../src/services/paymentGateway.js';

test('MODULE 06: CASH ON DELIVERY (COD) PAYMENTS, STATUS TRANSITIONS, AUDIT TIMELINE & INVOICING', async (t) => {
  let customerToken = '';
  let customerId = '';
  let otherCustomerToken = '';
  let deliveryPartnerToken = '';
  let deliveryPartnerId = '';
  let restaurantAdminToken = '';
  let restaurantAdminId = '';
  let restaurantId = '';
  let dish1Id = '';
  let orderId = '';
  let orderTotal = '';

  const timestamp = Date.now();

  await t.test('Setup: Create accounts, restaurant, menu item, and place test order', async () => {
    // 1. Customer
    const custEmail = `pay_cust_${timestamp}@example.com`;
    const custPhone = `7${String(timestamp).slice(-9)}`;
    const custReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Rohan Sharma',
        email: custEmail,
        phone: custPhone,
        password: 'Password123!',
        role: 'CUSTOMER',
        termsAccepted: true,
      });
    assert.equal(custReg.status, 201);
    customerId = custReg.body.data.user.id;

    const custLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: custEmail, password: 'Password123!' });
    assert.equal(custLogin.status, 200);
    customerToken = custLogin.body.data.token;

    // 2. Other Customer (for authorization tests)
    const otherEmail = `pay_other_${timestamp}@example.com`;
    const otherPhone = `6${String(timestamp).slice(-9)}`;
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Pooja Verma',
        email: otherEmail,
        phone: otherPhone,
        password: 'Password123!',
        role: 'CUSTOMER',
        termsAccepted: true,
      });
    const otherLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: otherEmail, password: 'Password123!' });
    otherCustomerToken = otherLogin.body.data.token;

    // 3. Delivery Partner
    const dpEmail = `pay_dp_${timestamp}@example.com`;
    const dpPhone = `8${String(timestamp).slice(-9)}`;
    const dpReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Vijay Rider',
        email: dpEmail,
        phone: dpPhone,
        password: 'Password123!',
        role: 'DELIVERY_PARTNER',
        termsAccepted: true,
      });
    assert.equal(dpReg.status, 201);
    deliveryPartnerId = dpReg.body.data.user.id;

    const dpLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: dpEmail, password: 'Password123!' });
    assert.equal(dpLogin.status, 200);
    deliveryPartnerToken = dpLogin.body.data.token;

    // 4. Restaurant Admin
    const ownerEmail = `pay_owner_${timestamp}@example.com`;
    const ownerPhone = `9${String(timestamp).slice(-9)}`;
    const ownerReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Chef Kapoor',
        email: ownerEmail,
        phone: ownerPhone,
        password: 'Password123!',
        role: 'RESTAURANT_ADMIN',
        termsAccepted: true,
      });
    assert.equal(ownerReg.status, 201);
    restaurantAdminId = ownerReg.body.data.user.id;

    const ownerLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: ownerEmail, password: 'Password123!' });
    assert.equal(ownerLogin.status, 200);
    restaurantAdminToken = ownerLogin.body.data.token;

    // 5. Create Test Restaurant
    const r1 = await pool.query(
      `INSERT INTO restaurants (owner_id, name, description, address, phone, cuisine_type, food_license_number, approval_status, is_open)
       VALUES ($1, $2, 'Authentic North Indian Thali and Parathas', '42 Ring Road, Cyber City, Gurugram', '9876543210', 'North Indian', 'FSSAI-11223344556677', 'APPROVED', true)
       RETURNING id`,
      [restaurantAdminId, `Kapoor Dhaba ${timestamp}`]
    );
    restaurantId = r1.rows[0].id;

    // 6. Create Category & Menu Item
    const c1 = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order) VALUES ($1, 'Thalis', 1) RETURNING id`,
      [restaurantId]
    );
    const catId = c1.rows[0].id;

    const d1 = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available)
       VALUES ($1, $2, 'Special Dal Makhani Thali', 'Rich creamy dal makhani with 2 butter naan and jeera rice', 250.00, true, true)
       RETURNING id`,
      [restaurantId, catId]
    );
    dish1Id = d1.rows[0].id;

    // 7. Customer Adds to Cart and Places Order
    await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ restaurantId, menuItemId: dish1Id, quantity: 2 });

    const orderRes = await request(app)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        deliveryAddress: 'Flat 502, Tower B, Green Valley Apartments, Gurugram',
        customerPhone: '9876543210',
        customerName: 'Rohan Sharma',
        specialInstructions: 'Ring doorbell twice please',
        idempotencyKey: `idemp-pay-${timestamp}`,
        paymentMethod: 'CASH_ON_DELIVERY',
      });
    assert.equal(orderRes.status, 201);
    orderId = orderRes.body.data.id;
    orderTotal = orderRes.body.data.totalAmount;
    assert.ok(orderId);
    assert.ok(parseFloat(orderTotal) > 0);
  });

  await t.test('PAY-01: Payment record automatically created upon order placement', async () => {
    const payRes = await request(app)
      .get(`/api/v1/orders/${orderId}/payment`)
      .set('Authorization', `Bearer ${customerToken}`);

    assert.equal(payRes.status, 200);
    assert.equal(payRes.body.success, true);
    assert.ok(payRes.body.data.payment);
    assert.equal(payRes.body.data.payment.orderId, orderId);
    assert.equal(payRes.body.data.payment.paymentMethod, 'CASH_ON_DELIVERY');
    assert.equal(payRes.body.data.payment.amount, orderTotal);
    assert.equal(payRes.body.data.payment.currency, 'INR');
    assert.equal(payRes.body.data.payment.collectedAt, null);
    assert.equal(payRes.body.data.payment.collectedByUserId, null);

    // Verify initial event in payment_events audit timeline
    const events = payRes.body.data.events;
    assert.ok(Array.isArray(events));
    assert.equal(events.length, 1);
    assert.equal(events[0].toStatus, 'PENDING');
    assert.equal(events[0].actorRole, 'CUSTOMER');
  });

  await t.test('PAY-02: Payment status remains PENDING / Due across fulfillment updates until collection', async () => {
    // Restaurant updates fulfillment status to CONFIRMED
    const confirmRes = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${restaurantAdminToken}`)
      .send({ status: 'CONFIRMED' });
    assert.equal(confirmRes.status, 200);

    // Verify payment status is STILL PENDING (Confirmation alone does NOT mark COD collected)
    const payRes = await request(app)
      .get(`/api/v1/orders/${orderId}/payment`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(payRes.status, 200);
    assert.equal(payRes.body.data.payment.paymentStatus, 'PENDING');
  });

  await t.test('PAY-03: Authorization check - Customers CANNOT collect their own payment (403 Forbidden)', async () => {
    const collectRes = await request(app)
      .post(`/api/v1/orders/${orderId}/payment/collect`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ note: 'Customer attempting self-collection' });

    assert.equal(collectRes.status, 403);
    assert.equal(collectRes.body.error.code, 'FORBIDDEN');
    assert.match(collectRes.body.error.message, /cannot mark their own/i);
  });

  await t.test('PAY-03: Authorization check - Unrelated customer cannot view another order payment (403)', async () => {
    const viewRes = await request(app)
      .get(`/api/v1/orders/${orderId}/payment`)
      .set('Authorization', `Bearer ${otherCustomerToken}`);

    assert.equal(viewRes.status, 403);
    assert.equal(viewRes.body.error.code, 'FORBIDDEN');
  });

  await t.test('PAY-03: Delivery partner records COD collection upon delivery handover', async () => {
    const txRef = `COD-TX-${timestamp}`;
    const collectRes = await request(app)
      .post(`/api/v1/orders/${orderId}/payment/collect`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({
        transactionReference: txRef,
        note: 'Cash received in full from customer at doorstep',
      });

    assert.equal(collectRes.status, 200);
    assert.equal(collectRes.body.success, true);
    assert.equal(collectRes.body.data.payment.paymentStatus, 'PAID');
    assert.equal(collectRes.body.data.payment.transactionReference, txRef);
    assert.equal(collectRes.body.data.payment.collectedByUserId, deliveryPartnerId);
    assert.ok(collectRes.body.data.payment.collectedAt !== null);
    assert.equal(collectRes.body.data.isAlreadyCollected, false);

    // Verify payment timeline has 2 events (PENDING -> PAID)
    const payRes = await request(app)
      .get(`/api/v1/orders/${orderId}/payment`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(payRes.status, 200);
    const events = payRes.body.data.events;
    assert.equal(events.length, 2);
    assert.equal(events[1].fromStatus, 'PENDING');
    assert.equal(events[1].toStatus, 'PAID');
    assert.equal(events[1].actorRole, 'DELIVERY_PARTNER');
    assert.equal(events[1].actorUserId, deliveryPartnerId);
  });

  await t.test('PAY-05: Idempotency - Subsequent collection calls return 200 with isAlreadyCollected: true', async () => {
    const duplicateCollectRes = await request(app)
      .post(`/api/v1/orders/${orderId}/payment/collect`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({ note: 'Duplicate call' });

    assert.equal(duplicateCollectRes.status, 200);
    assert.equal(duplicateCollectRes.body.data.isAlreadyCollected, true);
    assert.equal(duplicateCollectRes.body.data.payment.paymentStatus, 'PAID');

    // Confirm no duplicate audit event was generated
    const payRes = await request(app)
      .get(`/api/v1/orders/${orderId}/payment`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(payRes.body.data.events.length, 2);
  });

  await t.test('PAY-04: Generate and retrieve immutable tax invoice matching order snapshots', async () => {
    const invRes = await request(app)
      .get(`/api/v1/orders/${orderId}/invoice`)
      .set('Authorization', `Bearer ${customerToken}`);

    assert.equal(invRes.status, 200);
    assert.equal(invRes.body.success, true);
    const data = invRes.body.data;

    // Check invoice record
    assert.ok(data.invoice);
    assert.match(data.invoice.invoiceNumber, /^INV-\d{4}-\d{6}$/);
    assert.equal(data.invoice.orderId, orderId);
    assert.equal(data.invoice.totalAmount, orderTotal);
    assert.equal(data.invoice.currency, 'INR');

    // Check restaurant details
    assert.equal(data.restaurant.id, restaurantId);
    assert.equal(data.restaurant.foodLicenseNumber, 'FSSAI-11223344556677');

    // Check items match order snapshot
    assert.equal(data.items.length, 1);
    assert.equal(data.items[0].name, 'Special Dal Makhani Thali');
    assert.equal(data.items[0].quantity, 2);

    // Check fee breakdown
    assert.equal(data.breakdown.totalAmount, orderTotal);

    // Check payment state
    assert.equal(data.payment.status, 'PAID');
  });

  await t.test('PAY-04 & PAY-05: Invoice retrieval is idempotent (returns exact same invoice number)', async () => {
    const invRes1 = await request(app)
      .get(`/api/v1/orders/${orderId}/invoice`)
      .set('Authorization', `Bearer ${customerToken}`);

    const invRes2 = await request(app)
      .get(`/api/v1/orders/${orderId}/invoice`)
      .set('Authorization', `Bearer ${restaurantAdminToken}`);

    assert.equal(invRes1.status, 200);
    assert.equal(invRes2.status, 200);
    assert.equal(invRes1.body.data.invoice.invoiceNumber, invRes2.body.data.invoice.invoiceNumber);
    assert.equal(invRes1.body.data.invoice.id, invRes2.body.data.invoice.id);
  });

  await t.test('PAY-04: Printable Tax Invoice HTML endpoint returns text/html document', async () => {
    const printRes = await request(app)
      .get(`/api/v1/orders/${orderId}/invoice/print`)
      .set('Authorization', `Bearer ${customerToken}`);

    assert.equal(printRes.status, 200);
    assert.match(printRes.headers['content-type'], /text\/html/);
    assert.match(printRes.text, /Tax Invoice/);
    assert.match(printRes.text, /FSSAI Lic: FSSAI-11223344556677/);
    assert.match(printRes.text, /Special Dal Makhani Thali/);
    assert.match(printRes.text, /PAID via CASH_ON_DELIVERY/);
  });

  await t.test('PAY-06: Future Payment Gateway Adapter interface compliance', async () => {
    const codAdapter = new CashOnDeliveryAdapter();
    assert.equal(codAdapter.providerName, 'COD');

    const intent = await codAdapter.createPaymentIntent({
      orderId: 'test-order-uuid',
      amountPaise: 50000,
      currency: 'INR',
      customer: {
        id: 'cust-1',
        name: 'Rohan Sharma',
        email: 'test@example.com',
        phone: '9876543210',
      },
    });
    assert.equal(intent.provider, 'COD');
    assert.equal(intent.status, 'PENDING');

    const verified = await codAdapter.verifyPayment({
      orderId: 'test-order-uuid',
      paymentId: 'test-pay-uuid',
    });
    assert.equal(verified.verified, true);
    assert.equal(verified.status, 'PAID');

    // Future online gateway mock raises expected error when credentials not provided
    const mockOnline = new MockOnlinePaymentGatewayAdapter();
    await assert.rejects(
      async () => {
        await mockOnline.createPaymentIntent({
          orderId: 'test-order',
          amountPaise: 1000,
          currency: 'INR',
          customer: {
            id: 'cust-1',
            name: 'Rohan Sharma',
            phone: '9876543210',
          },
        });
      },
      /Online payment gateways are disabled in Release 1.0/
    );
  });

  // Teardown: Clean up test fixtures cleanly so dev DB remains pristine
  await t.test('Teardown: Clean up test fixtures', async () => {
    if (restaurantId) {
      const ids = [restaurantId];
      await pool.query('DELETE FROM cart_items WHERE cart_id IN (SELECT id FROM carts WHERE restaurant_id = ANY($1))', [ids]);
      await pool.query('DELETE FROM carts WHERE restaurant_id = ANY($1)', [ids]);
      await pool.query('DELETE FROM invoices WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1))', [ids]);
      await pool.query('DELETE FROM payment_events WHERE payment_id IN (SELECT id FROM payments WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1)))', [ids]);
      await pool.query('DELETE FROM payments WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1))', [ids]);
      await pool.query('DELETE FROM order_status_events WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1))', [ids]);
      await pool.query('DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1))', [ids]);
      await pool.query('DELETE FROM orders WHERE restaurant_id = ANY($1)', [ids]);
      await pool.query('DELETE FROM menu_items WHERE restaurant_id = ANY($1)', [ids]);
      await pool.query('DELETE FROM menu_categories WHERE restaurant_id = ANY($1)', [ids]);
      await pool.query('DELETE FROM operating_hours WHERE restaurant_id = ANY($1)', [ids]);
      await pool.query('DELETE FROM restaurants WHERE id = ANY($1)', [ids]);
    }
  });
});


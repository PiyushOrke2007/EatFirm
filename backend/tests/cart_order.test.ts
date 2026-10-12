import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/database/db.js';

test('MODULE 05: CART, CHECKOUT, ORDER PLACEMENT, HISTORY & CANCELLATION INTEGRATION TESTS', async (t) => {
  let customerToken = '';
  let customerId = '';
  let otherCustomerToken = '';
  let restaurantAdminToken = '';
  let restaurant1Id = '';
  let restaurant2Id = '';
  let dish1Id = ''; // Veg, ₹150.00
  let dish2Id = ''; // Non-veg, ₹300.00 regular, offer ₹250.00
  let dish3Id = ''; // Restaurant 2 dish, ₹180.00
  let unavailableDishId = '';

  const timestamp = Date.now();

  await t.test('Setup: Create accounts, restaurants, categories, and menu items', async () => {
    // 1. Customer 1
    const custEmail = `cust_ord_${timestamp}@example.com`;
    const custPhone = `7${String(timestamp).slice(-9)}`;
    const custReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'John Customer',
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

    // 2. Customer 2 (for authorization tests)
    const otherEmail = `other_cust_${timestamp}@example.com`;
    const otherPhone = `6${String(timestamp).slice(-9)}`;
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Alice Other',
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

    // 3. Restaurant Owner & Restaurant 1
    const ownerEmail = `owner_ord_${timestamp}@example.com`;
    const ownerPhone = `8${String(timestamp).slice(-9)}`;
    const ownerReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Chef Mario',
        email: ownerEmail,
        phone: ownerPhone,
        password: 'Password123!',
        role: 'RESTAURANT_ADMIN',
        termsAccepted: true,
      });
    const ownerId = ownerReg.body.data.user.id;

    const ownerLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: ownerEmail, password: 'Password123!' });
    restaurantAdminToken = ownerLogin.body.data.token;

    const r1 = await pool.query(
      `INSERT INTO restaurants (owner_id, name, description, address, phone, cuisine_type, food_license_number, approval_status, is_open)
       VALUES ($1, $2, 'Trattoria Italiano', '12 Brigade Rd, Bangalore', '9876543210', 'Italian', 'FSSAI-123456789012', 'APPROVED', true)
       RETURNING id`,
      [ownerId, `Mario Trattoria ${timestamp}`]
    );
    restaurant1Id = r1.rows[0].id;

    const c1 = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order) VALUES ($1, 'Pasta & Pizza', 1) RETURNING id`,
      [restaurant1Id]
    );
    const cat1Id = c1.rows[0].id;

    const d1 = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available)
       VALUES ($1, $2, 'Margherita Pizza', 'Fresh basil and mozzarella', 150.00, true, true)
       RETURNING id`,
      [restaurant1Id, cat1Id]
    );
    dish1Id = d1.rows[0].id;

    const d2 = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available, is_special_offer, offer_price)
       VALUES ($1, $2, 'Chicken Lasagna', 'Layers of handmade pasta and meat sauce', 300.00, false, true, true, 250.00)
       RETURNING id`,
      [restaurant1Id, cat1Id]
    );
    dish2Id = d2.rows[0].id;

    const dUnavail = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available)
       VALUES ($1, $2, 'Truffle Risotto', 'Seasonal delicacy', 450.00, true, false)
       RETURNING id`,
      [restaurant1Id, cat1Id]
    );
    unavailableDishId = dUnavail.rows[0].id;

    // 4. Restaurant Owner 2 & Restaurant 2 (for conflict test)
    const owner2Email = `owner2_ord_${timestamp}@example.com`;
    const owner2Phone = `89${String(timestamp).slice(-8)}`;
    const owner2Reg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Chef Nawab',
        email: owner2Email,
        phone: owner2Phone,
        password: 'Password123!',
        role: 'RESTAURANT_ADMIN',
        termsAccepted: true,
      });
    const owner2Id = owner2Reg.body.data.user.id;

    const r2 = await pool.query(
      `INSERT INTO restaurants (owner_id, name, description, address, phone, cuisine_type, food_license_number, approval_status, is_open)
       VALUES ($1, $2, 'Biryani Delights', '55 Church St, Bangalore', '9876543211', 'Mughlai', 'FSSAI-987654321098', 'APPROVED', true)
       RETURNING id`,
      [owner2Id, `Royal Biryani ${timestamp}`]
    );
    restaurant2Id = r2.rows[0].id;

    const c2 = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order) VALUES ($1, 'Biryani', 1) RETURNING id`,
      [restaurant2Id]
    );
    const d3 = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available)
       VALUES ($1, $2, 'Hyderabadi Veg Biryani', 'Fragrant basmati rice', 180.00, true, true)
       RETURNING id`,
      [restaurant2Id, c2.rows[0].id]
    );
    dish3Id = d3.rows[0].id;
  });

  // Test ORD-01 & CART-1, CART-2: Add to cart, view, update, instructions
  await t.test('ORD-01 & CART-1: Add item to cart with instructions and view live calculations', async () => {
    const addRes = await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        restaurantId: restaurant1Id,
        menuItemId: dish1Id,
        quantity: 2,
        itemInstructions: 'Make it extra crispy crust',
      });

    assert.equal(addRes.status, 201);
    const cart = addRes.body.data;
    assert.equal(cart.restaurantId, restaurant1Id);
    assert.equal(cart.itemCount, 2);
    assert.equal(cart.items.length, 1);
    assert.equal(cart.items[0].name, 'Margherita Pizza');
    assert.equal(cart.items[0].isVeg, true); // NFR-12
    assert.equal(cart.items[0].lineTotal, '300.00'); // 150 * 2
    assert.equal(cart.subtotal, '300.00');
    assert.equal(cart.deliveryFee, '30.00'); // Standard delivery fee (< ₹500)
    assert.equal(cart.taxAmount, '15.00'); // 5% of ₹300 = 15
    assert.equal(cart.totalAmount, '345.00'); // 300 + 30 + 15
  });

  await t.test('ORD-01: Update cart item quantity and overall cooking notes (CART-2)', async () => {
    // 1. Get current cart to retrieve cart item ID
    const cartRes = await request(app)
      .get('/api/v1/cart')
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(cartRes.status, 200);
    const cartItemId = cartRes.body.data.items[0].id;

    // 2. Add dish 2 (special offer price: ₹250 instead of ₹300)
    const add2 = await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        restaurantId: restaurant1Id,
        menuItemId: dish2Id,
        quantity: 1,
      });
    assert.equal(add2.status, 201);
    assert.equal(add2.body.data.itemCount, 3);
    assert.equal(add2.body.data.subtotal, '550.00'); // 300 + 250
    assert.equal(add2.body.data.deliveryFee, '0.00'); // Free delivery (>= ₹500)
    assert.equal(add2.body.data.taxAmount, '27.50'); // 5% of ₹550
    assert.equal(add2.body.data.totalAmount, '577.50'); // 550 + 27.50

    // 3. Update cart instructions
    const notesRes = await request(app)
      .patch('/api/v1/cart/instructions')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ specialInstructions: 'Please do not ring the doorbell' });
    assert.equal(notesRes.status, 200);
    assert.equal(notesRes.body.data.specialInstructions, 'Please do not ring the doorbell');

    // 4. Update quantity of dish 1 from 2 down to 1
    const updateRes = await request(app)
      .patch(`/api/v1/cart/items/${cartItemId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ quantity: 1 });
    assert.equal(updateRes.status, 200);
    assert.equal(updateRes.body.data.itemCount, 2);
  });

  // Test ORD-02: Single-restaurant cart conflict
  await t.test('ORD-02: Single-restaurant conflict check', async (t2) => {
    await t2.test('Rejects item from different restaurant with 409 conflict code', async () => {
      const conflictRes = await request(app)
        .post('/api/v1/cart/items')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          restaurantId: restaurant2Id,
          menuItemId: dish3Id,
          quantity: 1,
        });

      assert.equal(conflictRes.status, 409);
      assert.equal(conflictRes.body.error.code, 'DIFFERENT_RESTAURANT_CONFLICT');
    });

    await t2.test('Allows replaceCart=true to discard prior restaurant items', async () => {
      const replaceRes = await request(app)
        .post('/api/v1/cart/items')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          restaurantId: restaurant2Id,
          menuItemId: dish3Id,
          quantity: 2,
          replaceCart: true,
        });

      assert.equal(replaceRes.status, 201);
      assert.equal(replaceRes.body.data.restaurantId, restaurant2Id);
      assert.equal(replaceRes.body.data.itemCount, 2);
      assert.equal(replaceRes.body.data.items[0].name, 'Hyderabadi Veg Biryani');
    });
  });

  // Test Unavailable Dish Validation
  await t.test('ORD-03: Unavailable dish cannot be added to cart', async () => {
    const unavailRes = await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        restaurantId: restaurant1Id,
        menuItemId: unavailableDishId,
        quantity: 1,
        replaceCart: true,
      });

    assert.equal(unavailRes.status, 422);
  });

  // Test ORD-04 & ORD-05: Idempotent order placement and snapshot preservation
  let placedOrderId = '';
  const testIdempotencyKey = `idemp-${timestamp}-${Math.random()}`;

  await t.test('ORD-04 & ORD-05: Checkout and idempotent order placement', async () => {
    // 1. Prepare cart with Restaurant 1 dishes
    await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        restaurantId: restaurant1Id,
        menuItemId: dish1Id,
        quantity: 2,
        itemInstructions: 'Thin crust please',
        replaceCart: true,
      });

    // 2. Place Order
    const placeRes = await request(app)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        deliveryAddress: 'Flat 402, Sunshine Heights, Koramangala 4th Block',
        customerPhone: '9876543210',
        customerName: 'John Customer',
        specialInstructions: 'Leave package with security',
        idempotencyKey: testIdempotencyKey,
        paymentMethod: 'CASH_ON_DELIVERY',
      });

    assert.equal(placeRes.status, 201);
    const order = placeRes.body.data;
    placedOrderId = order.id;

    assert.ok(order.publicOrderNumber.startsWith('ORD-'));
    assert.equal(order.fulfillmentStatus, 'PLACED');
    assert.equal(order.paymentStatus, 'PENDING');
    assert.equal(order.paymentMethod, 'CASH_ON_DELIVERY');
    assert.equal(order.deliveryAddressSnapshot, 'Flat 402, Sunshine Heights, Koramangala 4th Block');
    assert.equal(order.subtotal, '300.00');
    assert.equal(order.deliveryFee, '30.00');
    assert.equal(order.taxAmount, '15.00');
    assert.equal(order.totalAmount, '345.00');
    assert.equal(order.items.length, 1);
    assert.equal(order.items[0].itemName, 'Margherita Pizza');
    assert.equal(order.items[0].isVeg, true); // NFR-12
    assert.equal(order.items[0].unitPrice, '150.00');
    assert.equal(order.items[0].quantity, 2);
    assert.equal(order.items[0].lineTotal, '300.00');

    // 3. Active cart should now be empty
    const cartAfter = await request(app)
      .get('/api/v1/cart')
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(cartAfter.status, 200);
    assert.equal(cartAfter.body.data, null);

    // 4. Retrying checkout with the SAME idempotency key must return the existing order (ORD-04)
    const retryRes = await request(app)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        deliveryAddress: 'Flat 402, Sunshine Heights, Koramangala 4th Block',
        customerPhone: '9876543210',
        customerName: 'John Customer',
        idempotencyKey: testIdempotencyKey,
      });

    assert.equal(retryRes.status, 200);
    assert.equal(retryRes.body.data.id, placedOrderId);
    assert.equal(retryRes.body.data.publicOrderNumber, order.publicOrderNumber);
  });

  // Test ORD-07: Order History and Order Details
  await t.test('ORD-07: Order History and Details verification', async () => {
    // 1. Customer lists orders
    const listRes = await request(app)
      .get('/api/v1/orders')
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(listRes.status, 200);
    assert.ok(listRes.body.data.length >= 1);
    assert.equal(listRes.body.data[0].id, placedOrderId);

    // 2. Customer gets single order details
    const detailRes = await request(app)
      .get(`/api/v1/orders/${placedOrderId}`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(detailRes.status, 200);
    assert.equal(detailRes.body.data.id, placedOrderId);
    assert.ok(detailRes.body.data.statusTimeline.length >= 1);
    assert.equal(detailRes.body.data.statusTimeline[0].toStatus, 'PLACED');

    // 3. Other customer cannot view this order (Security & ownership check)
    const forbiddenRes = await request(app)
      .get(`/api/v1/orders/${placedOrderId}`)
      .set('Authorization', `Bearer ${otherCustomerToken}`);
    assert.equal(forbiddenRes.status, 403);
  });

  // Test ORD-08, Section 6, NFR-14, NFR-16: Order Cancellation
  await t.test('ORD-08: Order Cancellation in PLACED status', async () => {
    // 1. Cancel order
    const cancelRes = await request(app)
      .post(`/api/v1/orders/${placedOrderId}/cancel`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ reason: 'Placed order by mistake, change of plans' });

    assert.equal(cancelRes.status, 200);
    assert.equal(cancelRes.body.data.fulfillmentStatus, 'CANCELLED');
    assert.equal(cancelRes.body.data.cancellationReason, 'Placed order by mistake, change of plans');
    assert.ok(cancelRes.body.data.cancelledAt !== null);

    // 2. Verify order timeline contains CANCELLED event
    const timeline = cancelRes.body.data.statusTimeline;
    assert.ok(timeline.some((e: any) => e.toStatus === 'CANCELLED'));

    // 3. Attempting to cancel again fails with 409
    const doubleCancelRes = await request(app)
      .post(`/api/v1/orders/${placedOrderId}/cancel`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ reason: 'Trying again' });
    assert.equal(doubleCancelRes.status, 409);

    // 4. Verify order is NOT deleted in database (SRS Section 6)
    const dbOrder = await pool.query('SELECT id, fulfillment_status FROM orders WHERE id = $1', [placedOrderId]);
    assert.equal(dbOrder.rows.length, 1);
    assert.equal(dbOrder.rows[0].fulfillment_status, 'CANCELLED');
  });
});

import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/database/db.js';

test('MODULE 07: ORDER PROGRESS, STATUS TIMELINE, AND TRACKING UPDATES INTEGRATION TESTS', async (t) => {
  let customerToken = '';
  let customerId = '';
  let otherCustomerToken = '';
  let deliveryPartnerToken = '';
  let deliveryPartnerId = '';
  let restaurantAdminToken = '';
  let restaurantAdminId = '';
  let restaurantId = '';
  let orderId = '';

  const timestamp = Date.now();

  await t.test('Setup: Create accounts, restaurant, menu item, and place test order', async () => {
    // 1. Customer
    const custEmail = `trk_cust_${timestamp}@example.com`;
    const custPhone = `7${String(timestamp).slice(-9)}`;
    const custReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Aakash Verma',
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

    // 2. Other Customer (for authorization checks)
    const otherEmail = `trk_other_${timestamp}@example.com`;
    const otherPhone = `6${String(timestamp).slice(-9)}`;
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Divya Nair',
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
    const dpEmail = `trk_dp_${timestamp}@example.com`;
    const dpPhone = `8${String(timestamp).slice(-9)}`;
    const dpReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Ramesh Rider',
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
    const ownerEmail = `trk_owner_${timestamp}@example.com`;
    const ownerPhone = `9${String(timestamp).slice(-9)}`;
    const ownerReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Chef Mehra',
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
    restaurantAdminToken = ownerLogin.body.data.token;

    // 5. Onboard & Approve Restaurant
    const restRes = await request(app)
      .post('/api/v1/restaurants/onboard')
      .set('Authorization', `Bearer ${restaurantAdminToken}`)
      .send({
        name: `Mehra Kitchen ${timestamp}`,
        address: '100 Feet Road, Indiranagar, Bengaluru',
        phone: '9876543210',
        cuisineType: 'North Indian',
        foodLicenseNumber: 'FSSAI-12345678901234',
        operatingHours: [
          { dayOfWeek: 'MONDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'TUESDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'WEDNESDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'THURSDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'FRIDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'SATURDAY', openTime: '10:00', closeTime: '23:00' },
          { dayOfWeek: 'SUNDAY', openTime: '10:00', closeTime: '23:00' },
        ],
      });
    assert.equal(restRes.status, 201);
    restaurantId = restRes.body.data.restaurant.id;

    // Approve restaurant directly in DB
    await pool.query("UPDATE restaurants SET approval_status = 'APPROVED', is_open = true WHERE id = $1", [restaurantId]);

    // 6. Category & Dish
    const c1 = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order) VALUES ($1, 'Mains', 1) RETURNING id`,
      [restaurantId]
    );
    const catId = c1.rows[0].id;

    const d1 = await pool.query(
      `INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_veg, is_available)
       VALUES ($1, $2, 'Dal Tadka Special', 'Yellow lentils tempered with ghee & spices', 220.00, true, true)
       RETURNING id`,
      [restaurantId, catId]
    );
    const dishId = d1.rows[0].id;

    // 7. Customer Adds to Cart & Places Order
    await request(app)
      .post('/api/v1/cart/items')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ restaurantId, menuItemId: dishId, quantity: 2 });

    const orderRes = await request(app)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({
        deliveryAddress: 'Flat 301, Palm Grove, Bengaluru',
        customerPhone: custPhone,
        customerName: 'Aakash Verma',
        idempotencyKey: `idemp-trk-${timestamp}`,
        paymentMethod: 'CASH_ON_DELIVERY',
      });
    assert.equal(orderRes.status, 201);
    orderId = orderRes.body.data.id;
  });

  await t.test('TRK-01: Retrieves initial tracking timeline with PLACED status', async () => {
    const res = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.orderId, orderId);
    assert.equal(res.body.data.fulfillmentStatus, 'PLACED');
    assert.equal(res.body.data.paymentStatus, 'PENDING');
    assert.equal(res.body.data.latestLocation, null);
    assert.ok(Array.isArray(res.body.data.statusTimeline));
    assert.ok(res.body.data.statusTimeline.length >= 1);
    assert.equal(res.body.data.statusTimeline[0].toStatus, 'PLACED');
  });

  await t.test('TRK-02: Enforces role permissions and authorized transitions', async () => {
    // 1. Cross-customer denial (403 Forbidden)
    const crossRes = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`)
      .set('Authorization', `Bearer ${otherCustomerToken}`);
    assert.equal(crossRes.status, 403);
    assert.equal(crossRes.body.error?.code, 'FORBIDDEN');

    // 2. Unauthenticated request (401 Unauthorized)
    const unauthRes = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`);
    assert.equal(unauthRes.status, 401);

    // 3. Customer cannot update status (403 Forbidden)
    const custUpdate = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ status: 'CONFIRMED' });
    assert.equal(custUpdate.status, 403);

    // 4. Restaurant Admin updates PLACED -> CONFIRMED
    const confRes = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${restaurantAdminToken}`)
      .send({ status: 'CONFIRMED', note: 'Kitchen accepted order' });
    assert.equal(confRes.status, 200);
    assert.equal(confRes.body.data.fulfillmentStatus, 'CONFIRMED');

    // 5. Restaurant Admin updates CONFIRMED -> PREPARING
    const prepRes = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${restaurantAdminToken}`)
      .send({ status: 'PREPARING', note: 'Chefs preparing food' });
    assert.equal(prepRes.status, 200);
    assert.equal(prepRes.body.data.fulfillmentStatus, 'PREPARING');

    // 6. Invalid transition rejection (PREPARING -> DELIVERED is invalid; must go to OUT_FOR_DELIVERY first)
    const invalidTrans = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${restaurantAdminToken}`)
      .send({ status: 'DELIVERED' });
    assert.equal(invalidTrans.status, 422);
  });

  await t.test('TRK-03 & TRK-04: Delivery partner marks OUT_FOR_DELIVERY and transmits GPS telemetry', async () => {
    // 1. Delivery partner updates status to OUT_FOR_DELIVERY
    const outRes = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({ status: 'OUT_FOR_DELIVERY', note: 'Picked up from restaurant counter' });
    assert.equal(outRes.status, 200);
    assert.equal(outRes.body.data.fulfillmentStatus, 'OUT_FOR_DELIVERY');

    // 2. Delivery partner cannot update to an unauthorized status like PREPARING
    const invalidPartnerUpdate = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({ status: 'PREPARING' });
    assert.equal(invalidPartnerUpdate.status, 403);

    // 3. Customer cannot record GPS telemetry (403 Forbidden)
    const custLocRes = await request(app)
      .post(`/api/v1/orders/${orderId}/tracking/location`)
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ latitude: 12.9716, longitude: 77.5946 });
    assert.equal(custLocRes.status, 403);

    // 4. Delivery partner records real GPS location
    const locPost = await request(app)
      .post(`/api/v1/orders/${orderId}/tracking/location`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({
        latitude: 12.9750,
        longitude: 77.6050,
        headingDegrees: 90.0,
        speedMetersPerSec: 8.5,
        accuracyMeters: 5.0,
      });
    assert.equal(locPost.status, 201);
    assert.equal(locPost.body.data.latitude, 12.975);
    assert.equal(locPost.body.data.longitude, 77.605);

    // 5. Customer fetches tracking with live partner location
    const trkRes = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);

    assert.equal(trkRes.status, 200);
    assert.equal(trkRes.body.data.fulfillmentStatus, 'OUT_FOR_DELIVERY');
    assert.ok(trkRes.body.data.latestLocation !== null);
    assert.equal(trkRes.body.data.latestLocation.latitude, 12.975);
    assert.equal(trkRes.body.data.latestLocation.longitude, 77.605);
    assert.ok(trkRes.body.data.assignedDeliveryPartner !== null);
    assert.equal(trkRes.body.data.assignedDeliveryPartner.name, 'Ramesh Rider');

    // Check chronological order of timeline events
    const timeline = trkRes.body.data.statusTimeline;
    assert.ok(timeline.length >= 3);
    const statuses = timeline.map((e: any) => e.toStatus);
    assert.deepEqual(statuses, ['PLACED', 'CONFIRMED', 'PREPARING', 'OUT_FOR_DELIVERY']);
  });

  await t.test('TRK-05: Delivery partner marks DELIVERED; Tracking reflects completion without mutating payment', async () => {
    // 1. Mark DELIVERED
    const delRes = await request(app)
      .patch(`/api/v1/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({ status: 'DELIVERED', note: 'Handed over to customer' });
    assert.equal(delRes.status, 200);
    assert.equal(delRes.body.data.fulfillmentStatus, 'DELIVERED');

    // 2. Verify tracking response shows DELIVERED while payment remains independent (PENDING until collection)
    const trkRes = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(trkRes.status, 200);
    assert.equal(trkRes.body.data.fulfillmentStatus, 'DELIVERED');
    assert.equal(trkRes.body.data.paymentStatus, 'PENDING');

    // 3. Record COD Cash Collection and verify independent update
    const payRes = await request(app)
      .post(`/api/v1/orders/${orderId}/payment/collect`)
      .set('Authorization', `Bearer ${deliveryPartnerToken}`)
      .send({ note: 'Cash received upon delivery' });
    assert.equal(payRes.status, 200);
    assert.equal(payRes.body.data.payment.paymentStatus, 'PAID');

    // 4. Tracking reflects paymentStatus = PAID
    const trkResAfterPay = await request(app)
      .get(`/api/v1/orders/${orderId}/tracking`)
      .set('Authorization', `Bearer ${customerToken}`);
    assert.equal(trkResAfterPay.status, 200);
    assert.equal(trkResAfterPay.body.data.paymentStatus, 'PAID');
  });

  // Teardown: Clean up test fixtures
  await t.test('Teardown: Clean up test fixtures', async () => {
    if (restaurantId) {
      const ids = [restaurantId];
      await pool.query('DELETE FROM order_tracking_locations WHERE order_id IN (SELECT id FROM orders WHERE restaurant_id = ANY($1))', [ids]);
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
      await pool.query('DELETE FROM restaurants WHERE id = ANY($1)', [ids]);
      await pool.query("DELETE FROM restaurants WHERE owner_id IN (SELECT id FROM users WHERE email LIKE 'trk_%@example.com')");
      await pool.query("DELETE FROM users WHERE email LIKE 'trk_%@example.com'");
    }
  });
});


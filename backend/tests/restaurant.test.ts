import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/database/db.js';

test('MODULE 03: RESTAURANT & MENU MANAGEMENT INTEGRATION TESTS', async (t) => {
  let restAdminToken = '';
  let restAdminId = '';
  let customerToken = '';
  let adminToken = '';
  let restaurantId = '';
  let categoryId = '';
  let menuItemId = '';

  const timestamp = Date.now();
  const restEmail = `rest_admin_${timestamp}@example.com`;
  const custEmail = `rest_cust_${timestamp}@example.com`;

  // 1. Setup Accounts
  await t.test('Setup: Create Restaurant Admin, Customer, and Login Admin', async () => {
    // Register Restaurant Admin
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Chef Gordon',
        email: restEmail,
        phone: `8${String(timestamp).slice(-9)}`,
        password: 'Password123!',
        role: 'RESTAURANT_ADMIN',
        termsAccepted: true,
      });
    assert.equal(regRes.status, 201);
    restAdminId = regRes.body.data.user.id;

    // Login Restaurant Admin
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: restEmail, password: 'Password123!' });
    assert.equal(loginRes.status, 200);
    restAdminToken = loginRes.body.data.token;

    // Register & Login Customer
    const custReg = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Hungry Customer',
        email: custEmail,
        phone: `7${String(timestamp).slice(-9)}`,
        password: 'Password123!',
        role: 'CUSTOMER',
        termsAccepted: true,
      });
    assert.equal(custReg.status, 201);

    const custLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: custEmail, password: 'Password123!' });
    assert.equal(custLogin.status, 200);
    customerToken = custLogin.body.data.token;

    // Login System Admin (Seeded in 002_auth)
    const adminLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: 'admin@eatfirm.com', password: 'Admin@EatFirm2026!' });
    assert.equal(adminLogin.status, 200);
    adminToken = adminLogin.body.data.token;
  });

  // 2. REST-01: Restaurant Onboarding
  await t.test('REST-01: Restaurant Onboarding', async (t2) => {
    await t2.test('Customer cannot onboard restaurant (403 Forbidden)', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/onboard')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          name: 'Unauthorized Cafe',
          address: '123 Fake Street',
          phone: '9876543210',
          cuisineType: 'Italian',
          foodLicenseNumber: 'FSSAI-12345678',
        });
      assert.equal(res.status, 403);
    });

    await t2.test('Fails onboarding with missing required food licence number (Section 6)', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/onboard')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          name: 'The Spice House',
          address: '42 Marine Drive, Mumbai',
          phone: '9876543210',
          cuisineType: 'North Indian',
          foodLicenseNumber: '',
        });
      assert.equal(res.status, 422);
    });

    await t2.test('Successfully onboards restaurant with operating hours', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/onboard')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          name: 'The Spice House',
          description: 'Authentic gourmet North Indian & Mughlai cuisine',
          address: '42 Marine Drive, Mumbai',
          phone: '9876543210',
          cuisineType: 'North Indian',
          foodLicenseNumber: 'FSSAI-98765432101234',
          imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
          operatingHours: [
            { dayOfWeek: 'MONDAY', openTime: '10:00', closeTime: '23:00', isClosed: false },
            { dayOfWeek: 'TUESDAY', openTime: '10:00', closeTime: '23:00', isClosed: false },
            { dayOfWeek: 'WEDNESDAY', openTime: '10:00', closeTime: '23:00', isClosed: false },
            { dayOfWeek: 'THURSDAY', openTime: '10:00', closeTime: '23:00', isClosed: false },
            { dayOfWeek: 'FRIDAY', openTime: '10:00', closeTime: '23:30', isClosed: false },
            { dayOfWeek: 'SATURDAY', openTime: '10:00', closeTime: '23:30', isClosed: false },
            { dayOfWeek: 'SUNDAY', openTime: '11:00', closeTime: '22:00', isClosed: false },
          ],
        });

      assert.equal(res.status, 201);
      assert.equal(res.body.success, true);
      const rest = res.body.data.restaurant;
      assert.ok(rest.id);
      restaurantId = rest.id;
      assert.equal(rest.name, 'The Spice House');
      assert.equal(rest.approvalStatus, 'PENDING_APPROVAL');
      assert.equal(rest.isOpen, true);
      assert.equal(rest.operatingHours.length, 7);
    });

    await t2.test('Prevents registering a second restaurant for the same owner (409 Conflict)', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/onboard')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          name: 'Duplicate Cafe',
          address: '123 Fake Street',
          phone: '9876543210',
          cuisineType: 'Italian',
          foodLicenseNumber: 'FSSAI-99999999',
        });
      assert.equal(res.status, 409);
    });
  });

  // 3. REST-02: Profile, Availability & Operating Hours
  await t.test('REST-02: Restaurant Profile & Operational Availability', async (t3) => {
    await t3.test('GET /restaurants/mine returns owner restaurant profile', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants/mine')
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.restaurant.id, restaurantId);
    });

    await t3.test('PATCH /restaurants/mine updates description and phone', async () => {
      const res = await request(app)
        .patch('/api/v1/restaurants/mine')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          description: 'Updated fine dining North Indian experience',
          phone: '9123456789',
        });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.restaurant.description, 'Updated fine dining North Indian experience');
      assert.equal(res.body.data.restaurant.phone, '9123456789');
    });

    await t3.test('PATCH /restaurants/mine/toggle-open toggles operational availability', async () => {
      const resClose = await request(app)
        .patch('/api/v1/restaurants/mine/toggle-open')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ isOpen: false });
      assert.equal(resClose.status, 200);
      assert.equal(resClose.body.data.restaurant.isOpen, false);

      const resOpen = await request(app)
        .patch('/api/v1/restaurants/mine/toggle-open')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ isOpen: true });
      assert.equal(resOpen.status, 200);
      assert.equal(resOpen.body.data.restaurant.isOpen, true);
    });

    await t3.test('PUT /restaurants/mine/operating-hours updates weekly hours', async () => {
      const res = await request(app)
        .put('/api/v1/restaurants/mine/operating-hours')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          operatingHours: [
            { dayOfWeek: 'MONDAY', openTime: '09:00', closeTime: '22:00', isClosed: false },
            { dayOfWeek: 'SUNDAY', openTime: '12:00', closeTime: '21:00', isClosed: true },
          ],
        });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.operatingHours.length, 2);
    });
  });

  // 4. REST-02: System Admin Approval Workflow
  await t.test('REST-02: System Admin Approval Workflow', async (t4) => {
    await t4.test('Restaurant Admin cannot approve restaurant (403 Forbidden)', async () => {
      const res = await request(app)
        .post(`/api/v1/restaurants/${restaurantId}/approve`)
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 403);
    });

    await t4.test('System Admin lists pending restaurants', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants/pending')
        .set('Authorization', `Bearer ${adminToken}`);
      assert.equal(res.status, 200);
      const pending = res.body.data.restaurants;
      assert.ok(pending.some((r: any) => r.id === restaurantId));
    });

    await t4.test('System Admin approves restaurant registration', async () => {
      const res = await request(app)
        .post(`/api/v1/restaurants/${restaurantId}/approve`)
        .set('Authorization', `Bearer ${adminToken}`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.restaurant.approvalStatus, 'APPROVED');
    });

    await t4.test('System Admin rejects restaurant registration with reason', async () => {
      // Create a temporary restaurant to reject
      const tempEmail = `temp_rest_${Date.now()}@example.com`;
      const tempReg = await request(app)
        .post('/api/v1/auth/register')
        .send({
          name: 'Temp Chef',
          email: tempEmail,
          phone: `6${String(Date.now()).slice(-9)}`,
          password: 'Password123!',
          role: 'RESTAURANT_ADMIN',
          termsAccepted: true,
        });
      const tempLogin = await request(app)
        .post('/api/v1/auth/login')
        .send({ identifier: tempEmail, password: 'Password123!' });
      const tempToken = tempLogin.body.data.token;

      const tempOnboard = await request(app)
        .post('/api/v1/restaurants/onboard')
        .set('Authorization', `Bearer ${tempToken}`)
        .send({
          name: 'Reject Me Cafe',
          address: 'Some Address',
          phone: '9876543210',
          cuisineType: 'Fast Food',
          foodLicenseNumber: 'INVALID-LIC',
        });
      const tempId = tempOnboard.body.data.restaurant.id;

      const rejectRes = await request(app)
        .post(`/api/v1/restaurants/${tempId}/reject`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ reason: 'Invalid or unverifiable food license number' });
      assert.equal(rejectRes.status, 200);
      assert.equal(rejectRes.body.data.restaurant.approvalStatus, 'REJECTED');
      assert.equal(rejectRes.body.data.restaurant.rejectionReason, 'Invalid or unverifiable food license number');
    });
  });

  // 5. REST-03: Menu Categories Management
  await t.test('REST-03: Menu Categories Management', async (t5) => {
    await t5.test('Creates category for restaurant', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/categories')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ name: 'Biryani Specialities', sortOrder: 1 });
      assert.equal(res.status, 201);
      categoryId = res.body.data.category.id;
      assert.equal(res.body.data.category.name, 'Biryani Specialities');
    });

    await t5.test('Prevents duplicate category name in same restaurant', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/categories')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ name: 'Biryani Specialities', sortOrder: 2 });
      assert.equal(res.status, 409);
    });

    await t5.test('Lists categories for restaurant', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants/mine/categories')
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 200);
      assert.ok(res.body.data.categories.length >= 1);
    });

    await t5.test('Updates category name and sort order', async () => {
      const res = await request(app)
        .patch(`/api/v1/restaurants/mine/categories/${categoryId}`)
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ name: 'Royal Biryanis', sortOrder: 1 });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.category.name, 'Royal Biryanis');
    });
  });

  // 6. REST-03, REST-04, REST-05, REST-06: Menu Items Management & Rules
  await t.test('REST-03..06: Menu Items CRUD, Availability, and Special Offers', async (t6) => {
    await t6.test('Fails adding menu item with negative price', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/menu-items')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          categoryId,
          name: 'Invalid Price Item',
          price: -50.0,
          isVeg: true,
        });
      assert.equal(res.status, 422);
    });

    await t6.test('Fails adding menu item to non-existent category', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/menu-items')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          categoryId: '00000000-0000-0000-0000-000000000000',
          name: 'Ghost Item',
          price: 150.0,
          isVeg: true,
        });
      assert.equal(res.status, 422);
    });

    await t6.test('Fails special offer where offer price >= base price (REST-6)', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/menu-items')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          categoryId,
          name: 'Bad Discount Biryani',
          price: 300.0,
          isVeg: false,
          isSpecialOffer: true,
          offerPrice: 350.0,
        });
      assert.equal(res.status, 422);
    });

    await t6.test('Creates menu item with veg tag, time-based availability, and special offer (REST-3..6)', async () => {
      const res = await request(app)
        .post('/api/v1/restaurants/mine/menu-items')
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({
          categoryId,
          name: 'Hyderabadi Dum Biryani',
          description: 'Slow-cooked aromatic basmati rice layered with spiced marinated meat',
          price: 350.0,
          isVeg: false,
          isAvailable: true,
          availableFrom: '11:30',
          availableUntil: '23:00',
          isSpecialOffer: true,
          offerPrice: 299.0,
        });

      assert.equal(res.status, 201);
      const item = res.body.data.menuItem;
      assert.ok(item.id);
      menuItemId = item.id;
      assert.equal(item.name, 'Hyderabadi Dum Biryani');
      assert.equal(item.price, '350.00');
      assert.equal(item.isVeg, false);
      assert.equal(item.isAvailable, true);
      assert.equal(item.availableFrom, '11:30');
      assert.equal(item.availableUntil, '23:00');
      assert.equal(item.isSpecialOffer, true);
      assert.equal(item.offerPrice, '299.00');
    });

    await t6.test('Toggles menu item temporary availability (REST-4)', async () => {
      const resUnavailable = await request(app)
        .patch(`/api/v1/restaurants/mine/menu-items/${menuItemId}/toggle-availability`)
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ isAvailable: false });
      assert.equal(resUnavailable.status, 200);
      assert.equal(resUnavailable.body.data.menuItem.isAvailable, false);

      const resAvailable = await request(app)
        .patch(`/api/v1/restaurants/mine/menu-items/${menuItemId}/toggle-availability`)
        .set('Authorization', `Bearer ${restAdminToken}`)
        .send({ isAvailable: true });
      assert.equal(resAvailable.status, 200);
      assert.equal(resAvailable.body.data.menuItem.isAvailable, true);
    });

    await t6.test('Prevents deleting category that contains active menu items', async () => {
      const res = await request(app)
        .delete(`/api/v1/restaurants/mine/categories/${categoryId}`)
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 422);
    });

    await t6.test('Deletes menu item (NFR-14)', async () => {
      const res = await request(app)
        .delete(`/api/v1/restaurants/mine/menu-items/${menuItemId}`)
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.message, 'Menu item deleted successfully');
    });

    await t6.test('Allows deleting category once all items are deleted', async () => {
      const res = await request(app)
        .delete(`/api/v1/restaurants/mine/categories/${categoryId}`)
        .set('Authorization', `Bearer ${restAdminToken}`);
      assert.equal(res.status, 200);
    });
  });

  // 7. Public & Customer Menu Read
  await t.test('Public Restaurant & Menu Endpoints', async () => {
    const res = await request(app).get(`/api/v1/restaurants/${restaurantId}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.data.restaurant.name, 'The Spice House');

    const menuRes = await request(app).get(`/api/v1/restaurants/${restaurantId}/menu`);
    assert.equal(menuRes.status, 200);
    assert.ok(menuRes.body.data.categories);
    assert.ok(menuRes.body.data.menuItems);
  });
});


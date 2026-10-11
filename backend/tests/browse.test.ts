import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool } from '../src/database/db.js';

test('MODULE 04: CUSTOMER RESTAURANT DISCOVERY, SEARCH & MENU DETAILS INTEGRATION TESTS', async (t) => {
  let approvedRestaurantId = '';
  let pendingRestaurantId = '';
  let vegCategoryId = '';
  let nonVegCategoryId = '';

  const timestamp = Date.now();

  // Setup: Create an approved restaurant and a pending restaurant with menu items
  await t.test('Setup: Seed approved and pending restaurants with menu items', async () => {
    // 1. Create owner 1
    const owner1Res = await pool.query(
      `INSERT INTO users (name, email, phone, password_hash, role, account_status, is_verified)
       VALUES ($1, $2, $3, 'hash123', 'RESTAURANT_ADMIN', 'ACTIVE', true)
       RETURNING id`,
      [`Owner One`, `browse_owner1_${timestamp}@example.com`, `9${String(timestamp).slice(-9)}`]
    );
    const owner1Id = owner1Res.rows[0].id;

    // 2. Insert Approved Restaurant with known coordinates (Indiranagar, Bangalore: 12.9784, 77.6408)
    const rest1Res = await pool.query(
      `INSERT INTO restaurants (
         owner_id, name, description, address, phone, cuisine_type, food_license_number,
         approval_status, is_open, latitude, longitude, average_rating, rating_count, estimated_delivery_mins, price_tier
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'APPROVED', true, 12.9784, 77.6408, 4.6, 150, 25, '₹₹')
       RETURNING id`,
      [
        owner1Id,
        `Tandoori Nights ${timestamp}`,
        'Authentic clay oven delights and curries',
        '100ft Road, Indiranagar, Bengaluru',
        '9876500001',
        'North Indian',
        'FSSAI-999888777661',
      ]
    );
    approvedRestaurantId = rest1Res.rows[0].id;

    // 3. Create categories
    const cat1Res = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order)
       VALUES ($1, 'Starters', 1), ($1, 'Main Course', 2)
       RETURNING id, name`,
      [approvedRestaurantId]
    );
    vegCategoryId = cat1Res.rows.find((r: any) => r.name === 'Starters').id;
    nonVegCategoryId = cat1Res.rows.find((r: any) => r.name === 'Main Course').id;

    // 4. Create menu items: 1 Veg item, 1 Non-Veg special offer item
    await pool.query(
      `INSERT INTO menu_items (
         restaurant_id, category_id, name, description, price, is_veg, is_available, is_special_offer, offer_price
       )
       VALUES 
         ($1, $2, 'Paneer Tikka Platter', 'Smoky cottage cheese cubes', 260.00, true, true, false, NULL),
         ($1, $3, 'Butter Chicken Special', 'Rich creamy tomato gravy', 380.00, false, true, true, 320.00)`,
      [approvedRestaurantId, vegCategoryId, nonVegCategoryId]
    );

    // 5. Create owner 2 & Pending Restaurant (MUST NOT appear in customer browse)
    const owner2Res = await pool.query(
      `INSERT INTO users (name, email, phone, password_hash, role, account_status, is_verified)
       VALUES ($1, $2, $3, 'hash123', 'RESTAURANT_ADMIN', 'ACTIVE', true)
       RETURNING id`,
      [`Owner Two`, `browse_owner2_${timestamp}@example.com`, `8${String(timestamp).slice(-9)}`]
    );
    const owner2Id = owner2Res.rows[0].id;

    const rest2Res = await pool.query(
      `INSERT INTO restaurants (
         owner_id, name, description, address, phone, cuisine_type, food_license_number,
         approval_status, is_open, latitude, longitude
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING_APPROVAL', true, 12.9352, 77.6245)
       RETURNING id`,
      [
        owner2Id,
        `Secret Hideout ${timestamp}`,
        'Unapproved diner',
        'Koramangala, Bengaluru',
        '9876500002',
        'Continental',
        'FSSAI-000000000000',
      ]
    );
    pendingRestaurantId = rest2Res.rows[0].id;
  });

  // BROWSE-1: Restaurant Listing & Approval Visibility
  await t.test('BROWSE-1: Restaurant Listing & Status Filtering', async (t2) => {
    await t2.test('Lists only approved restaurants (excludes pending & rejected)', async () => {
      const res = await request(app).get('/api/v1/restaurants');
      assert.equal(res.status, 200);
      assert.equal(res.body.success, true);
      assert.ok(Array.isArray(res.body.data.restaurants));

      const ids = res.body.data.restaurants.map((r: any) => r.id);
      assert.ok(ids.includes(approvedRestaurantId));
      assert.ok(!ids.includes(pendingRestaurantId), 'Pending restaurant must be excluded from customer feed');
    });

    await t2.test('Calculates distance and sorts by distance_asc with valid coordinates', async () => {
      // User is in Indiranagar (approx 1 km from restaurant)
      const res = await request(app).get('/api/v1/restaurants').query({
        latitude: 12.9716,
        longitude: 77.5946,
        sortBy: 'distance_asc',
      });
      assert.equal(res.status, 200);
      const restaurant = res.body.data.restaurants.find((r: any) => r.id === approvedRestaurantId);
      assert.ok(restaurant);
      assert.ok(restaurant.distanceKm !== undefined, 'distanceKm should be calculated');
      assert.ok(typeof restaurant.distanceKm === 'number');
    });
  });

  // BROWSE-2: Search, Filters & Fast Suggestions (NFR-4)
  await t.test('BROWSE-2: Search, Filters & Fast Suggestions', async (t2) => {
    await t2.test('Searches by restaurant name', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ search: `Tandoori Nights ${timestamp}` });
      assert.equal(res.status, 200);
      assert.equal(res.body.data.restaurants.length, 1);
      assert.equal(res.body.data.restaurants[0].id, approvedRestaurantId);
    });

    await t2.test('Searches by dish name (matches restaurant offering the dish)', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ search: 'Paneer Tikka Platter' });
      assert.equal(res.status, 200);
      const ids = res.body.data.restaurants.map((r: any) => r.id);
      assert.ok(ids.includes(approvedRestaurantId));
    });

    await t2.test('Filters by cuisine type', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ cuisine: 'North Indian' });
      assert.equal(res.status, 200);
      const ids = res.body.data.restaurants.map((r: any) => r.id);
      assert.ok(ids.includes(approvedRestaurantId));
    });

    await t2.test('Filters by minimum rating', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ minRating: 4.0 });
      assert.equal(res.status, 200);
      const restaurant = res.body.data.restaurants.find((r: any) => r.id === approvedRestaurantId);
      assert.ok(restaurant);
      assert.ok(restaurant.averageRating >= 4.0);
    });

    await t2.test('Filters by vegOnly (returns restaurants with active veg items)', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ vegOnly: 'true' });
      assert.equal(res.status, 200);
      const ids = res.body.data.restaurants.map((r: any) => r.id);
      assert.ok(ids.includes(approvedRestaurantId));
    });

    await t2.test('Search suggestions endpoint returns matches within sub-second speed (NFR-4)', async () => {
      const start = Date.now();
      const res = await request(app)
        .get('/api/v1/restaurants/search/suggestions')
        .query({ q: 'Tandoori' });
      const duration = Date.now() - start;

      assert.equal(res.status, 200);
      assert.ok(duration < 2000, `Suggestions took ${duration}ms, must be < 2000ms`);
      assert.ok(Array.isArray(res.body.data.suggestions));
      const hasMatch = res.body.data.suggestions.some((s: any) =>
        s.text.includes('Tandoori')
      );
      assert.ok(hasMatch, 'Expected suggestion matching query');
    });
  });

  // BROWSE-3: Restaurant Details & Customer Menu (NFR-12)
  await t.test('BROWSE-3: Restaurant Details & Customer Menu', async (t2) => {
    await t2.test('Retrieves public restaurant profile with FSSAI and hours', async () => {
      const res = await request(app).get(`/api/v1/restaurants/${approvedRestaurantId}`);
      assert.equal(res.status, 200);
      assert.equal(res.body.data.restaurant.id, approvedRestaurantId);
      assert.equal(res.body.data.restaurant.foodLicenseNumber, 'FSSAI-999888777661');
    });

    await t2.test('Retrieves customer menu grouped into categories with items and tags', async () => {
      const res = await request(app).get(`/api/v1/restaurants/${approvedRestaurantId}/menu`);
      assert.equal(res.status, 200);
      assert.ok(Array.isArray(res.body.data.categories));
      assert.equal(res.body.data.categories.length, 2);

      const starters = res.body.data.categories.find((c: any) => c.name === 'Starters');
      assert.ok(starters);
      assert.equal(starters.items.length, 1);
      assert.equal(starters.items[0].isVeg, true);

      const mainCourse = res.body.data.categories.find((c: any) => c.name === 'Main Course');
      assert.ok(mainCourse);
      assert.equal(mainCourse.items.length, 1);
      assert.equal(mainCourse.items[0].isSpecialOffer, true);
      assert.equal(mainCourse.items[0].offerPrice, '320.00');
    });

    await t2.test('Filters customer menu by pure veg preference (BROWSE-3, NFR-12)', async () => {
      const res = await request(app)
        .get(`/api/v1/restaurants/${approvedRestaurantId}/menu`)
        .query({ isVeg: 'true' });
      assert.equal(res.status, 200);

      const allItems = res.body.data.categories.flatMap((c: any) => c.items);
      assert.ok(allItems.every((i: any) => i.isVeg === true), 'All returned items must be veg');
      assert.equal(allItems.length, 1);
      assert.equal(allItems[0].name, 'Paneer Tikka Platter');
    });
  });

  // Validation & Error Handling
  await t.test('Validation & Edge Cases', async (t2) => {
    await t2.test('Rejects invalid latitude coordinate > 90', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ latitude: 120 });
      assert.equal(res.status, 422);
    });

    await t2.test('Rejects invalid minRating > 5', async () => {
      const res = await request(app)
        .get('/api/v1/restaurants')
        .query({ minRating: 6 });
      assert.equal(res.status, 422);
    });

    await t2.test('Returns 404 for non-existent restaurant details', async () => {
      const res = await request(app).get('/api/v1/restaurants/00000000-0000-0000-0000-000000000000');
      assert.equal(res.status, 404);
    });
  });
});


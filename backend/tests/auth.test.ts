import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { pool, closeDatabasePool } from '../src/database/db.js';

test('AUTH-01: User Registration', async (t) => {
  const timestamp = Date.now();
  const testEmail = `testuser_${timestamp}@example.com`;
  const testPhone = `98${Math.floor(10000000 + Math.random() * 90000000)}`;

  await t.test('Successfully registers a CUSTOMER with valid credentials and terms acceptance', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Alice Customer',
        email: testEmail,
        phone: testPhone,
        password: 'ValidPassword123!',
        role: 'CUSTOMER',
        termsAccepted: true,
      });

    assert.strictEqual(res.status, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.user.name, 'Alice Customer');
    assert.strictEqual(res.body.data.user.email, testEmail);
    assert.strictEqual(res.body.data.user.role, 'CUSTOMER');
    assert.strictEqual(res.body.data.user.isVerified, false);
    // Never expose password hash
    assert.strictEqual(res.body.data.user.password_hash, undefined);
    assert.strictEqual(res.body.data.user.password, undefined);
  });

  await t.test('Rejects registration with SYSTEM_ADMIN role (SRS REG-1)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Evil Hacker',
        email: `hacker_${timestamp}@example.com`,
        password: 'ValidPassword123!',
        role: 'SYSTEM_ADMIN',
        termsAccepted: true,
      });

    assert.strictEqual(res.status, 422);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.error.code, 'VALIDATION_ERROR');
    assert.ok(res.body.error.message.includes('System Administrator'));
  });

  await t.test('Rejects registration when terms are not accepted', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'No Terms User',
        email: `noterms_${timestamp}@example.com`,
        password: 'ValidPassword123!',
        role: 'CUSTOMER',
        termsAccepted: false,
      });

    assert.strictEqual(res.status, 422);
    assert.strictEqual(res.body.success, false);
  });

  await t.test('Rejects registration with weak password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Weak Pass User',
        email: `weakpass_${timestamp}@example.com`,
        password: 'weak',
        role: 'CUSTOMER',
        termsAccepted: true,
      });

    assert.strictEqual(res.status, 422);
    assert.strictEqual(res.body.success, false);
  });

  await t.test('Rejects registration with duplicate email (409 Conflict)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        name: 'Duplicate User',
        email: testEmail,
        password: 'ValidPassword123!',
        role: 'CUSTOMER',
        termsAccepted: true,
      });

    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.error.code, 'CONFLICT');
  });
});

test('AUTH-02 & AUTH-03: OTP Verification and Login Flow', async (t) => {
  const timestamp = Date.now();
  const email = `verify_${timestamp}@example.com`;
  const phone = `97${Math.floor(10000000 + Math.random() * 90000000)}`;
  const password = 'SecurePassword2026!';

  // 1. Register
  const regRes = await request(app)
    .post('/api/v1/auth/register')
    .send({
      name: 'Verify User',
      email,
      phone,
      password,
      role: 'DELIVERY_PARTNER',
      termsAccepted: true,
    });
  assert.strictEqual(regRes.status, 201);

  await t.test('Fails OTP verification with wrong code', async () => {
    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({
        target: email,
        otpCode: '000000',
        purpose: 'REGISTRATION',
      });

    assert.strictEqual(res.status, 422);
    assert.strictEqual(res.body.success, false);
  });

  await t.test('Successfully verifies account with generated OTP code', async () => {
    const otpQuery = await pool.query<{ otp_code: string }>(
      `SELECT otp_code FROM otps WHERE target = $1 AND purpose = 'REGISTRATION' AND is_used = FALSE`,
      [email]
    );
    assert.ok(otpQuery.rows.length > 0);
    const code = otpQuery.rows[0].otp_code;

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({
        target: email,
        otpCode: code,
        purpose: 'REGISTRATION',
      });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);

    // Verify user is now marked verified in database
    const userCheck = await pool.query<{ is_verified: boolean }>(
      `SELECT is_verified FROM users WHERE LOWER(email) = $1`,
      [email]
    );
    assert.strictEqual(userCheck.rows[0].is_verified, true);
  });

  await t.test('Prevents OTP replay attack (cannot reuse same code)', async () => {
    const otpQuery = await pool.query<{ otp_code: string }>(
      `SELECT otp_code FROM otps WHERE target = $1 AND purpose = 'REGISTRATION'`,
      [email]
    );
    const code = otpQuery.rows[0].otp_code;

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({
        target: email,
        otpCode: code,
        purpose: 'REGISTRATION',
      });

    assert.strictEqual(res.status, 422);
  });

  await t.test('Fails login with wrong password (safe generic error)', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        identifier: email,
        password: 'WrongPassword!',
      });

    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.error.code, 'UNAUTHORIZED');
    assert.strictEqual(res.body.error.message, 'Invalid email/phone or password');
  });

  await t.test('Successfully logs in with email and password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        identifier: email,
        password,
      });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.data.token);
    assert.strictEqual(res.body.data.user.email, email);
    assert.strictEqual(res.body.data.user.role, 'DELIVERY_PARTNER');
  });

  await t.test('Successfully logs in with phone number and password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        identifier: phone,
        password,
      });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.data.token);
  });
});

test('AUTH-04 & AUTH-05: RBAC and Session Revocation', async (t) => {
  const timestamp = Date.now();
  const customerEmail = `rbac_cust_${timestamp}@example.com`;
  const password = 'ValidPassword123!';

  // Register Customer
  await request(app)
    .post('/api/v1/auth/register')
    .send({
      name: 'Customer Bob',
      email: customerEmail,
      password,
      role: 'CUSTOMER',
      termsAccepted: true,
    });

  // Login Customer
  const custLogin = await request(app)
    .post('/api/v1/auth/login')
    .send({
      identifier: customerEmail,
      password,
    });
  const customerToken = custLogin.body.data.token;

  // Login Seeded Admin
  const adminLogin = await request(app)
    .post('/api/v1/auth/login')
    .send({
      identifier: 'admin@eatfirm.com',
      password: 'Admin@EatFirm2026!',
    });
  assert.strictEqual(adminLogin.status, 200);
  const adminToken = adminLogin.body.data.token;

  await t.test('GET /api/v1/auth/me succeeds with valid token', async () => {
    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${customerToken}`);

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.user.email, customerEmail);
  });

  await t.test('GET /api/v1/auth/me rejects unauthenticated request (401)', async () => {
    const res = await request(app).get('/api/v1/auth/me');
    assert.strictEqual(res.status, 401);
  });

  await t.test('Prevents role escalation: Customer cannot access SYSTEM_ADMIN endpoint (403)', async () => {
    const res = await request(app)
      .get('/api/v1/auth/admin-check')
      .set('Authorization', `Bearer ${customerToken}`);

    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.error.code, 'FORBIDDEN');
  });

  await t.test('Admin can access SYSTEM_ADMIN endpoint', async () => {
    const res = await request(app)
      .get('/api/v1/auth/admin-check')
      .set('Authorization', `Bearer ${adminToken}`);

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.role, 'SYSTEM_ADMIN');
  });

  await t.test('Logout revokes session, subsequent access fails (401)', async () => {
    const logoutRes = await request(app)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${customerToken}`);

    assert.strictEqual(logoutRes.status, 200);

    const checkRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${customerToken}`);

    assert.strictEqual(checkRes.status, 401);
  });
});

test('AUTH-06: Profile Management', async (t) => {
  const timestamp = Date.now();
  const email = `profile_${timestamp}@example.com`;
  const password = 'ValidPassword123!';

  await request(app)
    .post('/api/v1/auth/register')
    .send({
      name: 'Original Name',
      email,
      password,
      role: 'CUSTOMER',
      termsAccepted: true,
    });

  const loginRes = await request(app)
    .post('/api/v1/auth/login')
    .send({ identifier: email, password });
  const token = loginRes.body.data.token;

  await t.test('Updates profile name and phone', async () => {
    const newPhone = `96${Math.floor(10000000 + Math.random() * 90000000)}`;
    const res = await request(app)
      .patch('/api/v1/auth/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Updated Name',
        phone: newPhone,
      });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.user.name, 'Updated Name');
    assert.strictEqual(res.body.data.user.phone, newPhone);
  });
});

test('AUTH-02 (Password Reset Flow)', async (t) => {
  const timestamp = Date.now();
  const email = `pwreset_${timestamp}@example.com`;
  const originalPass = 'OriginalPass123!';
  const newPass = 'UpdatedPassword2026!';

  await request(app)
    .post('/api/v1/auth/register')
    .send({
      name: 'Reset User',
      email,
      password: originalPass,
      role: 'CUSTOMER',
      termsAccepted: true,
    });

  await t.test('Requests password reset OTP', async () => {
    const res = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({ identifier: email });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
  });

  await t.test('Resets password with valid OTP and logs in with new password', async () => {
    const otpQuery = await pool.query<{ otp_code: string }>(
      `SELECT otp_code FROM otps WHERE target = $1 AND purpose = 'PASSWORD_RESET' AND is_used = FALSE`,
      [email]
    );
    assert.ok(otpQuery.rows.length > 0);
    const code = otpQuery.rows[0].otp_code;

    const resetRes = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        identifier: email,
        otpCode: code,
        newPassword: newPass,
      });

    assert.strictEqual(resetRes.status, 200);

    // Old password should now fail
    const oldLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: email, password: originalPass });
    assert.strictEqual(oldLogin.status, 401);

    // New password should succeed
    const newLogin = await request(app)
      .post('/api/v1/auth/login')
      .send({ identifier: email, password: newPass });
    assert.strictEqual(newLogin.status, 200);
  });
});

test.after(async () => {
  await closeDatabasePool();
});


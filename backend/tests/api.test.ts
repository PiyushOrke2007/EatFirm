import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { app } from '../src/app.js';
import { closeDatabasePool } from '../src/database/db.js';

test('GET /api/v1/health returns 200 with standard envelope and liveness info', async () => {
  const res = await request(app).get('/api/v1/health');

  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.success, true);
  assert.strictEqual(res.body.data.status, 'ok');
  assert.strictEqual(res.body.data.service, 'eatfirm-backend');
  assert.ok(res.body.meta.requestId);
  assert.ok(res.body.meta.timestamp);
  assert.strictEqual(res.headers['x-request-id'], res.body.meta.requestId);
});

test('GET /api/v1/ready returns 200 when database and migrations are up to date', async () => {
  const res = await request(app).get('/api/v1/ready');

  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.success, true);
  assert.strictEqual(res.body.data.status, 'ready');
  assert.strictEqual(res.body.data.database.status, 'connected');
  assert.strictEqual(res.body.data.migrations.status, 'up_to_date');
});

test('Request ID header is respected if provided by client', async () => {
  const clientRequestId = 'custom-test-correlation-id-12345';
  const res = await request(app)
    .get('/api/v1/health')
    .set('X-Request-Id', clientRequestId);

  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.headers['x-request-id'], clientRequestId);
  assert.strictEqual(res.body.meta.requestId, clientRequestId);
});

test('Unknown route returns 404 with structured error envelope', async () => {
  const res = await request(app).get('/api/v1/non-existent-endpoint');

  assert.strictEqual(res.status, 404);
  assert.strictEqual(res.body.success, false);
  assert.strictEqual(res.body.error.code, 'NOT_FOUND');
  assert.ok(res.body.error.message.includes('Cannot GET /api/v1/non-existent-endpoint'));
  assert.ok(res.body.meta.requestId);
});

test.after(async () => {
  await closeDatabasePool();
});


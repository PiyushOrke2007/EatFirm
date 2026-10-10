import test from 'node:test';
import assert from 'node:assert/strict';
import express, { Request, Response } from 'express';
import request from 'supertest';
import { requestIdMiddleware } from '../src/middleware/requestId.js';
import { sendSuccess, sendError, sendPaginated } from '../src/utils/response.js';

test('sendSuccess sends compliant envelope', async () => {
  const app = express();
  app.use(requestIdMiddleware);
  app.get('/test-success', (_req: Request, res: Response) => {
    sendSuccess(res, { item: 'sample' }, 201);
  });

  const res = await request(app).get('/test-success');
  assert.strictEqual(res.status, 201);
  assert.strictEqual(res.body.success, true);
  assert.strictEqual(res.body.data.item, 'sample');
  assert.ok(res.body.meta.requestId);
  assert.ok(res.body.meta.timestamp);
});

test('sendError sends compliant error envelope', async () => {
  const app = express();
  app.use(requestIdMiddleware);
  app.get('/test-error', (_req: Request, res: Response) => {
    sendError(res, 400, 'INVALID_INPUT', 'The input was bad', [
      { field: 'phone', message: 'Invalid phone number' },
    ]);
  });

  const res = await request(app).get('/test-error');
  assert.strictEqual(res.status, 400);
  assert.strictEqual(res.body.success, false);
  assert.strictEqual(res.body.error.code, 'INVALID_INPUT');
  assert.strictEqual(res.body.error.message, 'The input was bad');
  assert.strictEqual(res.body.error.details.length, 1);
  assert.strictEqual(res.body.error.details[0].field, 'phone');
});

test('sendPaginated sends compliant pagination envelope', async () => {
  const app = express();
  app.use(requestIdMiddleware);
  app.get('/test-pagination', (_req: Request, res: Response) => {
    sendPaginated(res, ['a', 'b', 'c'], 1, 3, 10);
  });

  const res = await request(app).get('/test-pagination');
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.success, true);
  assert.strictEqual(res.body.data.items.length, 3);
  assert.strictEqual(res.body.data.pagination.page, 1);
  assert.strictEqual(res.body.data.pagination.limit, 3);
  assert.strictEqual(res.body.data.pagination.totalItems, 10);
  assert.strictEqual(res.body.data.pagination.totalPages, 4);
  assert.strictEqual(res.body.data.pagination.hasNext, true);
  assert.strictEqual(res.body.data.pagination.hasPrev, false);
});


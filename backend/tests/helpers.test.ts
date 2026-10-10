import test from 'node:test';
import assert from 'node:assert/strict';
import express, { Request, Response } from 'express';
import request from 'supertest';
import { parsePagination } from '../src/utils/response.js';
import { rateLimiter } from '../src/middleware/rateLimiter.js';

test('parsePagination parses valid page and limit', () => {
  const req = { query: { page: '3', limit: '25' } } as unknown as Request;
  const { page, limit, offset } = parsePagination(req);

  assert.strictEqual(page, 3);
  assert.strictEqual(limit, 25);
  assert.strictEqual(offset, 50); // (3 - 1) * 25
});

test('parsePagination clamps negative or invalid page and limit', () => {
  const req = { query: { page: '-1', limit: '999' } } as unknown as Request;
  const { page, limit, offset } = parsePagination(req, 20, 50);

  assert.strictEqual(page, 1);
  assert.strictEqual(limit, 50); // clamped to maxLimit
  assert.strictEqual(offset, 0);
});

test('rateLimiter blocks requests exceeding threshold', async () => {
  const app = express();
  const limiter = rateLimiter({ windowMs: 2000, maxRequests: 2 });
  app.get('/limited', limiter, (_req: Request, res: Response) => {
    res.json({ ok: true });
  });

  // Request 1: OK
  const res1 = await request(app).get('/limited');
  assert.strictEqual(res1.status, 200);

  // Request 2: OK
  const res2 = await request(app).get('/limited');
  assert.strictEqual(res2.status, 200);

  // Request 3: Blocked (429)
  const res3 = await request(app).get('/limited');
  assert.strictEqual(res3.status, 429);
  assert.strictEqual(res3.body.error.code, 'RATE_LIMIT_EXCEEDED');
});


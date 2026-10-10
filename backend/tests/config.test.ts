import test from 'node:test';
import assert from 'node:assert/strict';
import { config, getSanitizedConfig } from '../src/config/index.js';

test('Configuration loads with valid defaults', () => {
  assert.ok(config.PORT > 0);
  assert.ok(config.DB_PORT > 0);
  assert.ok(config.DB_NAME);
  assert.ok(config.JWT_SECRET.length >= 32);
});

test('getSanitizedConfig masks sensitive values', () => {
  const sanitized = getSanitizedConfig(config);
  assert.strictEqual(sanitized.JWT_SECRET, '********');
  if (config.DB_PASSWORD) {
    assert.strictEqual(sanitized.DB_PASSWORD, '********');
  }
});


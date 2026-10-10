import test from 'node:test';
import assert from 'node:assert/strict';
import { migrator } from '../src/database/migrator.js';
import { closeDatabasePool } from '../src/database/db.js';

test('Migrator lists available migrations and status', async () => {
  const migrations = migrator.getAvailableMigrations();
  assert.ok(migrations.length >= 1);
  assert.strictEqual(migrations[0].version, '001');
  assert.strictEqual(migrations[0].name, 'foundation');

  const statuses = await migrator.status();
  assert.ok(statuses.length >= 1);
  assert.strictEqual(statuses[0].status, 'applied');
});

test.after(async () => {
  await closeDatabasePool();
});


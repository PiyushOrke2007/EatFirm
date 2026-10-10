import pg from 'pg';
import { config } from '../config/index.js';
import { logger } from '../logger/index.js';

const { Pool } = pg;

export const pool = new Pool({
  host: config.DB_HOST,
  port: config.DB_PORT,
  database: config.DB_NAME,
  user: config.DB_USER,
  password: config.DB_PASSWORD,
  ssl: config.DB_SSL ? { rejectUnauthorized: false } : false,
  max: config.DB_POOL_MAX,
  connectionTimeoutMillis: config.DB_TIMEOUT_MS,
  idleTimeoutMillis: 30000,
});

pool.on('error', (err) => {
  logger.error('Unexpected error on idle PostgreSQL client', { error: err.message });
});

/**
 * Execute a parameterized SQL query safely.
 */
export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<pg.QueryResult<T>> {
  const start = Date.now();
  try {
    const res = await pool.query<T>(text, params);
    const duration = Date.now() - start;
    logger.debug('Executed query', { text, duration, rows: res.rowCount });
    return res;
  } catch (err: unknown) {
    const error = err as Error;
    logger.error('Database query error', { text, error: error.message });
    throw err;
  }
}

/**
 * Run a multi-step callback inside a PostgreSQL transaction.
 * Automatically commits if successful, or rolls back on any error.
 */
export async function withTransaction<T>(
  callback: (client: pg.PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Transaction rolled back due to error', {
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Check if the database is reachable.
 */
export async function checkDatabaseConnection(): Promise<{ ok: boolean; latencyMs: number; error?: string }> {
  const start = Date.now();
  try {
    await pool.query('SELECT 1 AS health_check');
    const latencyMs = Date.now() - start;
    return { ok: true, latencyMs };
  } catch (error: unknown) {
    const latencyMs = Date.now() - start;
    const msg = error instanceof Error ? error.message : 'Unknown database error';
    return { ok: false, latencyMs, error: msg };
  }
}

/**
 * Close database pool (useful for test tear-down and server shutdown).
 */
export async function closeDatabasePool(): Promise<void> {
  await pool.end();
}


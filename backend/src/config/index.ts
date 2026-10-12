import dotenv from 'dotenv';
import path from 'path';
import { z } from 'zod';

// Load .env file (supports running from repository root or backend directory)
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
dotenv.config({ path: path.resolve(process.cwd(), 'backend', '.env') });

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(5000),
  HOST: z.string().default('0.0.0.0'),

  DB_HOST: z.string().min(1).default('127.0.0.1'),
  DB_PORT: z.coerce.number().int().positive().default(5432),
  DB_NAME: z.string().min(1).default('eatfirm_dev'),
  DB_USER: z.string().min(1).default('eatfirm'),
  DB_PASSWORD: z.string().default(''),
  DB_SSL: z
    .string()
    .transform((val) => val === 'true')
    .default('false'),
  DB_POOL_MAX: z.coerce.number().int().positive().default(20),
  DB_TIMEOUT_MS: z.coerce.number().int().positive().default(10000),

  CORS_ORIGIN: z.string().default('*'),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters long').default(
    'eatfirm_development_jwt_secret_key_minimum_32_characters_foundation'
  ),

  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'http', 'debug']).default('info'),
});

export type Config = z.infer<typeof configSchema>;

function loadConfig(): Config {
  const result = configSchema.safeParse(process.env);
  if (!result.success) {
    const errorDetails = result.error.errors
      .map((err) => `${err.path.join('.')}: ${err.message}`)
      .join('\n');
    console.error('CRITICAL: Invalid environment configuration:\n' + errorDetails);
    throw new Error('Invalid environment configuration:\n' + errorDetails);
  }
  return result.data;
}

export const config = loadConfig();

/**
 * Returns a sanitized copy of the config suitable for diagnostics/health logs,
 * with secrets masked.
 */
export function getSanitizedConfig(cfg: Config = config): Record<string, unknown> {
  return {
    ...cfg,
    DB_PASSWORD: cfg.DB_PASSWORD ? '********' : '',
    JWT_SECRET: '********',
  };
}


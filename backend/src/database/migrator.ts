import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import { pool, withTransaction } from './db.js';
import { logger } from '../logger/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface MigrationFile {
  version: string;
  name: string;
  upPath: string;
  downPath?: string;
}

export class Migrator {
  private migrationsDir: string;

  constructor(migrationsDir?: string) {
    this.migrationsDir = migrationsDir || path.resolve(__dirname, 'migrations');
  }

  async init(): Promise<void> {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(50) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `);
  }

  getAvailableMigrations(): MigrationFile[] {
    if (!fs.existsSync(this.migrationsDir)) {
      return [];
    }

    const files = fs.readdirSync(this.migrationsDir);
    const upFiles = files.filter((f) => f.endsWith('.sql') && !f.endsWith('.down.sql'));

    const migrations: MigrationFile[] = upFiles.map((file) => {
      const match = file.match(/^(\d+)_(.+)\.sql$/);
      if (!match) {
        throw new Error(`Invalid migration file format: "${file}". Expected "001_name.sql"`);
      }
      const [, version, name] = match;
      const downFilename = `${version}_${name}.down.sql`;
      const downPath = path.join(this.migrationsDir, downFilename);

      return {
        version,
        name,
        upPath: path.join(this.migrationsDir, file),
        downPath: fs.existsSync(downPath) ? downPath : undefined,
      };
    });

    return migrations.sort((a, b) => a.version.localeCompare(b.version));
  }

  async getAppliedMigrations(): Promise<{ version: string; name: string; applied_at: Date }[]> {
    await this.init();
    const res = await pool.query<{ version: string; name: string; applied_at: Date }>(
      `SELECT version, name, applied_at FROM schema_migrations ORDER BY version ASC;`
    );
    return res.rows;
  }

  async up(): Promise<{ applied: string[] }> {
    await this.init();
    const available = this.getAvailableMigrations();
    const applied = await this.getAppliedMigrations();
    const appliedVersions = new Set(applied.map((m) => m.version));

    const newlyApplied: string[] = [];

    for (const mig of available) {
      if (!appliedVersions.has(mig.version)) {
        logger.info(`Applying migration: ${mig.version}_${mig.name}...`);
        const sql = fs.readFileSync(mig.upPath, 'utf8');

        await withTransaction(async (client: pg.PoolClient) => {
          await client.query(sql);
          await client.query(
            `INSERT INTO schema_migrations (version, name, applied_at) VALUES ($1, $2, CURRENT_TIMESTAMP);`,
            [mig.version, mig.name]
          );
        });

        logger.info(`Successfully applied migration: ${mig.version}_${mig.name}`);
        newlyApplied.push(`${mig.version}_${mig.name}`);
      }
    }

    return { applied: newlyApplied };
  }

  async down(): Promise<{ rolledBack?: string }> {
    await this.init();
    const applied = await this.getAppliedMigrations();
    if (applied.length === 0) {
      logger.info('No migrations to rollback.');
      return {};
    }

    const latest = applied[applied.length - 1];
    const available = this.getAvailableMigrations();
    const target = available.find((m) => m.version === latest.version);

    if (!target || !target.downPath) {
      throw new Error(
        `Cannot rollback migration ${latest.version}_${latest.name}: missing corresponding .down.sql file.`
      );
    }

    logger.info(`Rolling back migration: ${target.version}_${target.name}...`);
    const sql = fs.readFileSync(target.downPath, 'utf8');

    await withTransaction(async (client: pg.PoolClient) => {
      await client.query(sql);
      await client.query(`DELETE FROM schema_migrations WHERE version = $1;`, [latest.version]);
    });

    logger.info(`Successfully rolled back migration: ${target.version}_${target.name}`);
    return { rolledBack: `${target.version}_${target.name}` };
  }

  async status(): Promise<{ version: string; name: string; status: 'applied' | 'pending'; appliedAt?: Date }[]> {
    await this.init();
    const available = this.getAvailableMigrations();
    const applied = await this.getAppliedMigrations();
    const appliedMap = new Map(applied.map((m) => [m.version, m.applied_at]));

    return available.map((mig) => ({
      version: mig.version,
      name: mig.name,
      status: appliedMap.has(mig.version) ? 'applied' : 'pending',
      appliedAt: appliedMap.get(mig.version),
    }));
  }
}

export const migrator = new Migrator();


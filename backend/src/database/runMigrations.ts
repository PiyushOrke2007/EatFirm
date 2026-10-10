import { migrator } from './migrator.js';
import { closeDatabasePool } from './db.js';
import { logger } from '../logger/index.js';

async function main() {
  const command = process.argv[2] || 'up';

  try {
    if (command === 'up') {
      logger.info('Running pending migrations...');
      const result = await migrator.up();
      if (result.applied.length === 0) {
        logger.info('Database schema is already up to date.');
      } else {
        logger.info(`Applied ${result.applied.length} migration(s): ${result.applied.join(', ')}`);
      }
    } else if (command === 'down') {
      logger.info('Rolling back latest migration...');
      const result = await migrator.down();
      if (result.rolledBack) {
        logger.info(`Rolled back migration: ${result.rolledBack}`);
      } else {
        logger.info('No migration to roll back.');
      }
    } else if (command === 'status') {
      const statuses = await migrator.status();
      console.table(statuses);
    } else {
      console.error(`Unknown command "${command}". Available commands: up, down, status`);
      process.exit(1);
    }
  } catch (error) {
    logger.error('Migration failed', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    process.exit(1);
  } finally {
    await closeDatabasePool();
  }
}

main();


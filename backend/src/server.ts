import http from 'http';
import { app } from './app.js';
import { config, getSanitizedConfig } from './config/index.js';
import { logger } from './logger/index.js';
import { checkDatabaseConnection, closeDatabasePool } from './database/db.js';

async function bootstrap() {
  logger.info('Starting EatFirm Backend Server...', {
    env: config.NODE_ENV,
    port: config.PORT,
    config: getSanitizedConfig(),
  });

  // Verify database connectivity at startup
  const dbHealth = await checkDatabaseConnection();
  if (dbHealth.ok) {
    logger.info('Connected to PostgreSQL successfully', { latencyMs: dbHealth.latencyMs });
  } else {
    logger.warn('Initial PostgreSQL connection failed', { error: dbHealth.error });
  }

  const server = http.createServer(app);

  server.listen(config.PORT, config.HOST, () => {
    logger.info(`EatFirm REST API listening on http://${config.HOST}:${config.PORT}/api/v1`);
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info(`Received ${signal}. Shutting down gracefully...`);
    server.close(async () => {
      logger.info('HTTP server closed.');
      try {
        await closeDatabasePool();
        logger.info('Database pool closed.');
        process.exit(0);
      } catch (err) {
        logger.error('Error closing database pool', { error: (err as Error).message });
        process.exit(1);
      }
    });

    // Force close after 10 seconds if hanging
    setTimeout(() => {
      logger.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrap().catch((error) => {
  logger.error('Fatal server bootstrap error', {
    error: error.message,
    stack: error.stack,
  });
  process.exit(1);
});


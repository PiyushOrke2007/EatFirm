import { Router, Request, Response } from 'express';
import { checkDatabaseConnection } from '../database/db.js';
import { migrator } from '../database/migrator.js';
import { sendSuccess, sendError } from '../utils/response.js';

export const healthRouter = Router();

/**
 * GET /api/v1/health
 * Liveness probe: Confirms that the API server is up and accepting HTTP traffic.
 */
healthRouter.get('/health', (_req: Request, res: Response) => {
  sendSuccess(res, {
    status: 'ok',
    service: 'eatfirm-backend',
    version: '1.0.0',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /api/v1/ready
 * Readiness probe: Verifies critical infrastructure (PostgreSQL connection and migration status).
 */
healthRouter.get('/ready', async (_req: Request, res: Response) => {
  const dbHealth = await checkDatabaseConnection();

  let migrationSummary = {
    status: 'unknown',
    total: 0,
    applied: 0,
    pending: 0,
  };

  if (dbHealth.ok) {
    try {
      const statuses = await migrator.status();
      const appliedCount = statuses.filter((s) => s.status === 'applied').length;
      const pendingCount = statuses.filter((s) => s.status === 'pending').length;

      migrationSummary = {
        status: pendingCount === 0 ? 'up_to_date' : 'pending_migrations',
        total: statuses.length,
        applied: appliedCount,
        pending: pendingCount,
      };
    } catch {
      migrationSummary.status = 'error';
    }
  }

  const isReady = dbHealth.ok && migrationSummary.status === 'up_to_date';

  if (isReady) {
    sendSuccess(res, {
      status: 'ready',
      database: {
        status: 'connected',
        latencyMs: dbHealth.latencyMs,
      },
      migrations: migrationSummary,
    });
  } else {
    sendError(
      res,
      503,
      'SERVICE_UNAVAILABLE',
      'System is not ready to serve traffic',
      [
        {
          field: 'database',
          message: dbHealth.ok ? 'connected' : `Database connection failed: ${dbHealth.error}`,
        },
        {
          field: 'migrations',
          message: migrationSummary.status,
        },
      ]
    );
  }
});


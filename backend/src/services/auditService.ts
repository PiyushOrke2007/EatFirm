import { pool } from '../database/db.js';
import { logger } from '../logger/index.js';

export interface AuditLogEntry {
  action: string;
  actorId?: string | null;
  actorRole?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  details?: Record<string, unknown> | null;
}

/**
 * Audit Service (SRS NFR-27):
 * Persists immutable security and administrative events to audit_logs.
 * Never throws exceptions to prevent failing core business operations.
 */
export async function logAuditEvent(entry: AuditLogEntry): Promise<void> {
  try {
    await pool.query(
      `INSERT INTO audit_logs (action, actor_id, actor_role, ip_address, user_agent, details, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)`,
      [
        entry.action,
        entry.actorId || null,
        entry.actorRole || null,
        entry.ipAddress || null,
        entry.userAgent || null,
        entry.details ? JSON.stringify(entry.details) : null,
      ]
    );
  } catch (error) {
    logger.error('Failed to write audit log entry', {
      action: entry.action,
      actorId: entry.actorId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}


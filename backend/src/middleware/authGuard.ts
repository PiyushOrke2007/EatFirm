import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { UnauthorizedError, ForbiddenError } from './errorHandler.js';
import { pool } from '../database/db.js';
import { config } from '../config/index.js';

export type UserRole = 'CUSTOMER' | 'RESTAURANT_ADMIN' | 'DELIVERY_PARTNER' | 'SYSTEM_ADMIN';

export interface AuthUser {
  id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
  role: UserRole;
  isVerified: boolean;
  accountStatus: string;
  sessionId: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
      token?: string;
    }
  }
}

/**
 * Extracts and decodes Bearer token from Authorization header,
 * validates against active database sessions in user_sessions table.
 */
export async function authenticateToken(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, config.JWT_SECRET) as { sub: string; role: UserRole };
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    const result = await pool.query(
      `SELECT
         s.id AS session_id,
         s.user_id,
         s.expires_at,
         s.revoked_at,
         u.name,
         u.email,
         u.phone,
         u.role,
         u.account_status,
         u.is_verified
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE s.token_hash = $1
       LIMIT 1`,
      [tokenHash]
    );

    if (result.rows.length === 0) {
      throw new UnauthorizedError('Invalid or expired session');
    }

    const session = result.rows[0];

    if (session.revoked_at !== null) {
      throw new UnauthorizedError('Session has been revoked. Please log in again.');
    }

    if (new Date(session.expires_at) < new Date()) {
      throw new UnauthorizedError('Session has expired. Please log in again.');
    }

    if (session.account_status === 'SUSPENDED' || session.account_status === 'DEACTIVATED') {
      throw new ForbiddenError('Account is suspended or deactivated');
    }

    req.user = {
      id: session.user_id,
      name: session.name,
      email: session.email,
      phone: session.phone,
      role: session.role,
      isVerified: Boolean(session.is_verified),
      accountStatus: session.account_status,
      sessionId: session.session_id,
    };
    req.token = token;

    next();
  } catch (error) {
    if (error instanceof UnauthorizedError || error instanceof ForbiddenError) {
      next(error);
    } else {
      next(new UnauthorizedError('Invalid or expired authentication token'));
    }
  }
}

/**
 * Enforces authenticated state (SRS LOGIN-1, LOGIN-3).
 */
export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  if (!req.user) {
    throw new UnauthorizedError('Authentication token or session required');
  }
  next();
}

/**
 * Role-Based Access Control (RBAC) Middleware:
 * Restricts access to specified roles (enforced on the backend per SRS NFR-20 and AUTH-05).
 */
export function requireRoles(...allowedRoles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }

    if (!allowedRoles.includes(req.user.role)) {
      throw new ForbiddenError(
        `Action requires one of the following roles: [${allowedRoles.join(', ')}]. Current role: ${req.user.role}`
      );
    }

    next();
  };
}

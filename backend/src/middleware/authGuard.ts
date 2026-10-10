import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError, ForbiddenError } from './errorHandler.js';

export type UserRole = 'CUSTOMER' | 'RESTAURANT_ADMIN' | 'DELIVERY_PARTNER' | 'SYSTEM_ADMIN';

export interface AuthUser {
  id: string;
  email?: string;
  phone?: string;
  role: UserRole;
  restaurantId?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

/**
 * Foundation Auth Middleware:
 * Verifies authenticated state. (Module 02 will connect token decoding).
 */
export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  if (!req.user) {
    throw new UnauthorizedError('Authentication token or session required');
  }
  next();
}

/**
 * Foundation Role-Based Access Control (RBAC) Middleware:
 * Restricts access to specified roles (enforced on the backend per SRS NFR-20 and LOGIN-3).
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


import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { sendError, ApiErrorDetail } from '../utils/response.js';
import { logger } from '../logger/index.js';
import { config } from '../config/index.js';

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly details?: ApiErrorDetail[];

  constructor(message: string, statusCode = 500, code = 'INTERNAL_SERVER_ERROR', details?: ApiErrorDetail[]) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: ApiErrorDetail[]) {
    super(message, 422, 'VALIDATION_ERROR', details);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Requested resource was not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Access forbidden for your role or credentials') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409, 'CONFLICT');
  }
}

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const requestId = req.id || 'unknown';

  // 1. Zod schema validation errors
  if (err instanceof ZodError) {
    const details: ApiErrorDetail[] = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
      code: e.code,
    }));

    logger.warn('Request validation failed', {
      requestId,
      path: req.originalUrl,
      details,
    });

    sendError(res, 422, 'VALIDATION_ERROR', 'Request validation failed', details);
    return;
  }

  // 2. Custom AppErrors (typed operational errors)
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(`Server error: ${err.message}`, {
        requestId,
        code: err.code,
        stack: err.stack,
      });
    } else {
      logger.warn(`Client error [${err.statusCode}]: ${err.message}`, {
        requestId,
        code: err.code,
      });
    }

    sendError(res, err.statusCode, err.code, err.message, err.details);
    return;
  }

  // 3. Express body parsing JSON syntax error
  if ('type' in err && (err as { type?: string }).type === 'entity.parse.failed') {
    sendError(res, 400, 'BAD_REQUEST', 'Invalid JSON payload received');
    return;
  }

  // 4. Unexpected server errors (500)
  logger.error(`Unhandled server exception: ${err.message}`, {
    requestId,
    name: err.name,
    stack: err.stack,
  });

  // Safe message in production to prevent leaking internals
  const safeMessage =
    config.NODE_ENV === 'production'
      ? 'An internal server error occurred. Please contact support with the request ID.'
      : err.message || 'An unexpected internal error occurred';

  sendError(res, 500, 'INTERNAL_SERVER_ERROR', safeMessage);
}


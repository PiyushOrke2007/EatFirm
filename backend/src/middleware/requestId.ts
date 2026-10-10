import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4, validate as uuidValidate } from 'uuid';

declare global {
  namespace Express {
    interface Request {
      id: string;
    }
  }
}

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const incomingId = (req.headers['x-request-id'] || req.headers['x-correlation-id']) as string | undefined;

  // Use incoming ID if valid UUID or reasonably formatted string (max 64 chars)
  const requestId =
    incomingId && incomingId.length <= 64 && /^[a-zA-Z0-9_-]+$/.test(incomingId)
      ? incomingId
      : uuidv4();

  req.id = requestId;
  res.setHeader('X-Request-Id', requestId);
  next();
}


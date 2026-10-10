import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/response.js';

interface RateLimitRecord {
  count: number;
  resetTime: number;
}

/**
 * Creates an in-memory rate limiter middleware adhering to SRS NFR-25 and CO-8.
 * Limits request frequency per IP or key within a sliding time window.
 */
export function rateLimiter(options: {
  windowMs: number;
  maxRequests: number;
  message?: string;
  keyGenerator?: (req: Request) => string;
}) {
  const {
    windowMs,
    maxRequests,
    message = 'Too many requests. Please try again later.',
    keyGenerator = (req) => req.ip || req.socket.remoteAddress || 'unknown-ip',
  } = options;

  const hits = new Map<string, RateLimitRecord>();

  // Cleanup expired windows periodically
  const cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [key, record] of hits.entries()) {
      if (now > record.resetTime) {
        hits.delete(key);
      }
    }
  }, Math.max(windowMs, 30000));

  cleanupInterval.unref();

  return (req: Request, res: Response, next: NextFunction): void => {
    const key = keyGenerator(req);
    const now = Date.now();

    const record = hits.get(key);

    if (!record || now > record.resetTime) {
      hits.set(key, { count: 1, resetTime: now + windowMs });
      res.setHeader('X-RateLimit-Limit', maxRequests);
      res.setHeader('X-RateLimit-Remaining', maxRequests - 1);
      next();
      return;
    }

    if (record.count >= maxRequests) {
      const retryAfterSeconds = Math.ceil((record.resetTime - now) / 1000);
      res.setHeader('Retry-After', retryAfterSeconds);
      res.setHeader('X-RateLimit-Limit', maxRequests);
      res.setHeader('X-RateLimit-Remaining', 0);

      sendError(
        res,
        429,
        'RATE_LIMIT_EXCEEDED',
        message,
        [
          {
            field: 'rateLimit',
            message: `Rate limit of ${maxRequests} requests per ${Math.round(windowMs / 1000)}s exceeded. Try again in ${retryAfterSeconds}s.`,
          },
        ]
      );
      return;
    }

    record.count += 1;
    res.setHeader('X-RateLimit-Limit', maxRequests);
    res.setHeader('X-RateLimit-Remaining', maxRequests - record.count);
    next();
  };
}


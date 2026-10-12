import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { config } from './config/index.js';
import { requestIdMiddleware } from './middleware/requestId.js';
import { requestLoggerMiddleware } from './middleware/requestLogger.js';
import { errorHandler, NotFoundError } from './middleware/errorHandler.js';
import { healthRouter } from './routes/health.js';
import { authRouter } from './routes/auth.js';
import { restaurantRouter } from './routes/restaurant.js';
import { cartRouter } from './routes/cart.js';
import { orderRouter } from './routes/order.js';
import { paymentRouter } from './routes/payment.js';
import { authenticateToken } from './middleware/authGuard.js';

export function createApp(): Express {
  const app = express();

  // Trust proxy for accurate client IP detection when behind reverse proxy
  app.set('trust proxy', true);

  // Security & Cross-Origin Resource Sharing
  app.use(
    cors({
      origin: config.CORS_ORIGIN === '*' ? true : config.CORS_ORIGIN.split(','),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'X-Correlation-Id'],
    })
  );

  // Body Parsing with safe size limit (prevent denial of service)
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // Correlation ID and structured HTTP logging
  app.use(requestIdMiddleware);
  app.use(requestLoggerMiddleware);

  // Decode JWT and attach session user if provided
  app.use(authenticateToken);

  // Versioned API Routes (/api/v1)
  app.use('/api/v1', healthRouter);
  app.use('/api/v1', authRouter);
  app.use('/api/v1', restaurantRouter);
  app.use('/api/v1', cartRouter);
  app.use('/api/v1', orderRouter);
  app.use('/api/v1', paymentRouter);

  // Fallback for undefined routes
  app.use((req: Request, _res: Response, next: NextFunction) => {
    next(new NotFoundError(`Cannot ${req.method} ${req.originalUrl}`));
  });

  // Centralized Error Handler
  app.use(errorHandler);

  return app;
}

export const app = createApp();


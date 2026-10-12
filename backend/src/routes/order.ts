import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { OrderService } from '../services/orderService.js';
import { sendSuccess } from '../utils/response.js';
import { requireAuth, requireRoles } from '../middleware/authGuard.js';

export const orderRouter = Router();

const createOrderSchema = z.object({
  deliveryAddress: z.string().min(5, 'Delivery address must be at least 5 characters').max(500),
  customerPhone: z.string().regex(/^\d{10}$/, 'Must be a valid 10-digit phone number'),
  customerName: z.string().min(2, 'Name must be at least 2 characters').max(100),
  specialInstructions: z.string().max(500).optional(),
  isScheduled: z.boolean().optional(),
  scheduledFor: z.string().datetime().optional(),
  idempotencyKey: z.string().min(1, 'Idempotency key is required').max(100),
  paymentMethod: z.literal('CASH_ON_DELIVERY').optional(),
});

const cancelOrderSchema = z.object({
  reason: z.string().min(3, 'Cancellation reason must be at least 3 characters').max(500),
});

const updateStatusSchema = z.object({
  status: z.enum(['CONFIRMED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
  note: z.string().max(500).optional(),
});

/**
 * POST /api/v1/orders
 * Places an order from the active cart with idempotency and backend-calculated pricing.
 */
orderRouter.post(
  '/orders',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const parsed = createOrderSchema.parse(req.body);
      const userAgent = Array.isArray(req.headers['user-agent'])
        ? req.headers['user-agent'][0]
        : req.headers['user-agent'];
      const result = await OrderService.createOrderFromCart(
        req.user!.id,
        parsed,
        req.ip,
        userAgent
      );
      sendSuccess(res, result.order, result.isExisting ? 200 : 201);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * GET /api/v1/orders
 * Lists historical orders for the current authenticated user (customer or restaurant owner).
 */
orderRouter.get(
  '/orders',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const status = typeof req.query.status === 'string' ? req.query.status : undefined;
      const limit = typeof req.query.limit === 'string' ? parseInt(req.query.limit, 10) : 20;
      const offset = typeof req.query.offset === 'string' ? parseInt(req.query.offset, 10) : 0;

      const result = await OrderService.listOrders(req.user!.id, req.user!.role, {
        status,
        limit,
        offset,
      });

      sendSuccess(res, result.orders, 200, {
        total: result.total,
        limit,
        offset,
      });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * GET /api/v1/orders/:id
 * Retrieves full details, snapshots, and timeline for a single order.
 */
orderRouter.get(
  '/orders/:id',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const order = await OrderService.getOrderById(
        req.user!.id,
        req.user!.role,
        orderId
      );
      sendSuccess(res, order, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * POST /api/v1/orders/:id/cancel
 * Cancels an order in eligible lifecycle states (SRS ORD-08, Section 6, NFR-14, NFR-16).
 */
orderRouter.post(
  '/orders/:id/cancel',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const parsed = cancelOrderSchema.parse(req.body);
      const userAgent = Array.isArray(req.headers['user-agent'])
        ? req.headers['user-agent'][0]
        : req.headers['user-agent'];
      const order = await OrderService.cancelOrder(
        req.user!.id,
        req.user!.role,
        orderId,
        parsed,
        req.ip,
        userAgent
      );
      sendSuccess(res, order, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * PATCH /api/v1/orders/:id/status
 * Updates order fulfillment status (Restricted to Restaurant Admin or System Admin).
 */
orderRouter.patch(
  '/orders/:id/status',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN', 'SYSTEM_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const parsed = updateStatusSchema.parse(req.body);
      const order = await OrderService.updateFulfillmentStatus(
        req.user!.id,
        req.user!.role,
        orderId,
        parsed.status,
        parsed.note
      );
      sendSuccess(res, order, 200);
    } catch (err) {
      next(err);
    }
  }
);

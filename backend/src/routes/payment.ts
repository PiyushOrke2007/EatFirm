import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { paymentService } from '../services/paymentService.js';
import { sendSuccess } from '../utils/response.js';
import { requireAuth } from '../middleware/authGuard.js';

export const paymentRouter = Router();

const recordCollectionSchema = z.object({
  transactionReference: z.string().max(100).optional(),
  note: z.string().max(500).optional(),
});

/**
 * GET /api/v1/orders/:id/payment
 * Retrieves authoritative payment record and audit timeline for an order (PAY-01, PAY-02).
 */
paymentRouter.get(
  '/orders/:id/payment',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const result = await paymentService.getPaymentByOrderId(
        orderId,
        req.user!.id,
        req.user!.role
      );
      sendSuccess(res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * POST /api/v1/orders/:id/payment/collect
 * Records cash collection for Cash On Delivery orders (PAY-02, PAY-03, PAY-05).
 * Enforces role restriction (DELIVERY_PARTNER, RESTAURANT_ADMIN, SYSTEM_ADMIN only; CUSTOMER receives 403).
 */
paymentRouter.post(
  '/orders/:id/payment/collect',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const parsed = recordCollectionSchema.parse(req.body || {});
      const result = await paymentService.recordCollection(
        orderId,
        req.user!.id,
        req.user!.role,
        parsed
      );
      sendSuccess(res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * GET /api/v1/orders/:id/invoice
 * Generates or retrieves an immutable tax invoice matching order snapshots (PAY-04, PAY-05).
 */
paymentRouter.get(
  '/orders/:id/invoice',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const invoice = await paymentService.getOrCreateInvoice(
        orderId,
        req.user!.id,
        req.user!.role
      );
      sendSuccess(res, invoice, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * GET /api/v1/orders/:id/invoice/print
 * Returns a printable HTML document of the official tax invoice (PAY-04).
 */
paymentRouter.get(
  '/orders/:id/invoice/print',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const orderId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const invoice = await paymentService.getOrCreateInvoice(
        orderId,
        req.user!.id,
        req.user!.role
      );
      const html = paymentService.generateInvoiceHtml(invoice);
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.status(200).send(html);
    } catch (err) {
      next(err);
    }
  }
);


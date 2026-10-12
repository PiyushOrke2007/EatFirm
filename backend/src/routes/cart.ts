import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { CartService } from '../services/cartService.js';
import { sendSuccess } from '../utils/response.js';
import { requireAuth } from '../middleware/authGuard.js';

export const cartRouter = Router();

const addToCartSchema = z.object({
  restaurantId: z.string().uuid(),
  menuItemId: z.string().uuid(),
  quantity: z.number().int().min(1).max(99),
  itemInstructions: z.string().max(255).optional(),
  replaceCart: z.boolean().optional(),
});

const updateCartItemSchema = z.object({
  quantity: z.number().int().min(0).max(99),
  itemInstructions: z.string().max(255).optional(),
});

const updateCartNotesSchema = z.object({
  specialInstructions: z.string().max(500).optional(),
});

/**
 * GET /api/v1/cart
 * Retrieves the authenticated customer's current cart with real-time price calculations.
 */
cartRouter.get(
  '/cart',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const cart = await CartService.getCart(req.user!.id);
      sendSuccess(res, cart, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * POST /api/v1/cart/items
 * Adds a dish to the active cart with single-restaurant conflict enforcement.
 */
cartRouter.post(
  '/cart/items',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const parsed = addToCartSchema.parse(req.body);
      const cart = await CartService.addToCart(req.user!.id, parsed);
      sendSuccess(res, cart, 201);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * PATCH /api/v1/cart/items/:id
 * Updates quantity or special instructions for an existing cart item.
 */
cartRouter.patch(
  '/cart/items/:id',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const itemId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const parsed = updateCartItemSchema.parse(req.body);
      const cart = await CartService.updateCartItem(req.user!.id, itemId, parsed);
      sendSuccess(res, cart, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * DELETE /api/v1/cart/items/:id
 * Removes an item from the cart.
 */
cartRouter.delete(
  '/cart/items/:id',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const itemId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const cart = await CartService.removeCartItem(req.user!.id, itemId);
      sendSuccess(res, cart, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * PATCH /api/v1/cart/instructions
 * Updates chef cooking instructions for the overall cart (SRS CART-2).
 */
cartRouter.patch(
  '/cart/instructions',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const parsed = updateCartNotesSchema.parse(req.body);
      const cart = await CartService.updateCartNotes(req.user!.id, parsed);
      sendSuccess(res, cart, 200);
    } catch (err) {
      next(err);
    }
  }
);

/**
 * DELETE /api/v1/cart
 * Clears the customer's cart entirely.
 */
cartRouter.delete(
  '/cart',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await CartService.clearCart(req.user!.id);
      sendSuccess(res, null, 200);
    } catch (err) {
      next(err);
    }
  }
);


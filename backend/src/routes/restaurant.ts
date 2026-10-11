import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { RestaurantService } from '../services/restaurantService.js';
import { sendSuccess } from '../utils/response.js';
import { requireAuth, requireRoles } from '../middleware/authGuard.js';

export const restaurantRouter = Router();

const onboardSchema = z.object({
  name: z.string().min(2).max(255),
  description: z.string().optional(),
  address: z.string().min(5),
  phone: z.string().regex(/^\d{10}$/, 'Must be a valid 10-digit phone number'),
  cuisineType: z.string().min(2).max(100),
  foodLicenseNumber: z.string().min(3).max(100),
  imageUrl: z.string().url().optional().or(z.literal('')),
  operatingHours: z
    .array(
      z.object({
        dayOfWeek: z.enum([
          'MONDAY',
          'TUESDAY',
          'WEDNESDAY',
          'THURSDAY',
          'FRIDAY',
          'SATURDAY',
          'SUNDAY',
        ]),
        openTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time (HH:MM)'),
        closeTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time (HH:MM)'),
        isClosed: z.boolean().optional(),
      })
    )
    .optional(),
});

const updateProfileSchema = z.object({
  name: z.string().min(2).max(255).optional(),
  description: z.string().optional(),
  address: z.string().min(5).optional(),
  phone: z.string().regex(/^\d{10}$/, 'Must be a valid 10-digit phone number').optional(),
  cuisineType: z.string().min(2).max(100).optional(),
  foodLicenseNumber: z.string().min(3).max(100).optional(),
  imageUrl: z.string().url().optional().or(z.literal('')),
});

const toggleOpenSchema = z.object({
  isOpen: z.boolean(),
});

const operatingHoursSchema = z.object({
  operatingHours: z.array(
    z.object({
      dayOfWeek: z.enum([
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY',
        'SUNDAY',
      ]),
      openTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time (HH:MM)'),
      closeTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time (HH:MM)'),
      isClosed: z.boolean().optional(),
    })
  ),
});

const rejectSchema = z.object({
  reason: z.string().min(3).max(500),
});

const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
  sortOrder: z.number().int().optional(),
});

const updateCategorySchema = z.object({
  name: z.string().min(1).max(100).optional(),
  sortOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

const createMenuItemSchema = z.object({
  categoryId: z.string().uuid(),
  name: z.string().min(1).max(200),
  description: z.string().optional(),
  price: z.union([z.number().positive(), z.string()]),
  isVeg: z.boolean().optional(),
  imageUrl: z.string().url().optional().or(z.literal('')),
  isAvailable: z.boolean().optional(),
  availableFrom: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).nullable().optional(),
  availableUntil: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).nullable().optional(),
  isSpecialOffer: z.boolean().optional(),
  offerPrice: z.union([z.number().positive(), z.string()]).nullable().optional(),
});

const updateMenuItemSchema = z.object({
  categoryId: z.string().uuid().optional(),
  name: z.string().min(1).max(200).optional(),
  description: z.string().optional(),
  price: z.union([z.number().positive(), z.string()]).optional(),
  isVeg: z.boolean().optional(),
  imageUrl: z.string().url().optional().or(z.literal('')),
  isAvailable: z.boolean().optional(),
  availableFrom: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).nullable().optional(),
  availableUntil: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).nullable().optional(),
  isSpecialOffer: z.boolean().optional(),
  offerPrice: z.union([z.number().positive(), z.string()]).nullable().optional(),
});

const toggleAvailabilitySchema = z.object({
  isAvailable: z.boolean(),
});

/**
 * 1. RESTAURANT ADMIN WORKFLOW (SRS REST-1, REST-2, REST-3, REST-4, REST-5, REST-6)
 */

// Onboard restaurant
restaurantRouter.post(
  '/restaurants/onboard',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = onboardSchema.parse(req.body);
      const restaurant = await RestaurantService.onboardRestaurant(
        req.user!.id,
        validated as any,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { restaurant }, 201);
    } catch (err) {
      next(err);
    }
  }
);

// Get my restaurant
restaurantRouter.get(
  '/restaurants/mine',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurant = await RestaurantService.getMyRestaurant(req.user!.id);
      sendSuccess(res, { restaurant });
    } catch (err) {
      next(err);
    }
  }
);

// Update my restaurant profile
restaurantRouter.patch(
  '/restaurants/mine',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = updateProfileSchema.parse(req.body);
      const restaurant = await RestaurantService.updateRestaurantProfile(
        req.user!.id,
        validated as any,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { restaurant });
    } catch (err) {
      next(err);
    }
  }
);

// Toggle open/closed
restaurantRouter.patch(
  '/restaurants/mine/toggle-open',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = toggleOpenSchema.parse(req.body);
      const restaurant = await RestaurantService.toggleRestaurantOpen(
        req.user!.id,
        validated.isOpen,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { restaurant });
    } catch (err) {
      next(err);
    }
  }
);

// Update operating hours
restaurantRouter.put(
  '/restaurants/mine/operating-hours',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = operatingHoursSchema.parse(req.body);
      const operatingHours = await RestaurantService.updateOperatingHours(
        req.user!.id,
        validated.operatingHours as any
      );
      sendSuccess(res, { operatingHours });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * 2. CATEGORIES WORKFLOW (SRS REST-3)
 */

restaurantRouter.get(
  '/restaurants/mine/categories',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const myRes = await RestaurantService.getMyRestaurant(req.user!.id);
      if (!myRes) {
        sendSuccess(res, { categories: [] });
        return;
      }
      const categories = await RestaurantService.getCategories(myRes.id);
      sendSuccess(res, { categories });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.post(
  '/restaurants/mine/categories',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = createCategorySchema.parse(req.body);
      const category = await RestaurantService.createCategory(req.user!.id, validated);
      sendSuccess(res, { category }, 201);
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.patch(
  '/restaurants/mine/categories/:categoryId',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const categoryId = Array.isArray(req.params.categoryId) ? req.params.categoryId[0] : req.params.categoryId;
      const validated = updateCategorySchema.parse(req.body);
      const category = await RestaurantService.updateCategory(
        req.user!.id,
        categoryId,
        validated
      );
      sendSuccess(res, { category });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.delete(
  '/restaurants/mine/categories/:categoryId',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const categoryId = Array.isArray(req.params.categoryId) ? req.params.categoryId[0] : req.params.categoryId;
      await RestaurantService.deleteCategory(req.user!.id, categoryId);
      sendSuccess(res, { message: 'Category deleted successfully' });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * 3. MENU ITEMS WORKFLOW (SRS REST-3, REST-4, REST-5, REST-6)
 */

restaurantRouter.get(
  '/restaurants/mine/menu-items',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const myRes = await RestaurantService.getMyRestaurant(req.user!.id);
      if (!myRes) {
        sendSuccess(res, { menuItems: [] });
        return;
      }
      const categoryId = req.query.categoryId as string | undefined;
      const items = await RestaurantService.getMenuItems(myRes.id, categoryId, false);
      sendSuccess(res, { menuItems: items });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.post(
  '/restaurants/mine/menu-items',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const validated = createMenuItemSchema.parse(req.body);
      const menuItem = await RestaurantService.createMenuItem(
        req.user!.id,
        validated as any,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { menuItem }, 201);
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.patch(
  '/restaurants/mine/menu-items/:itemId',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const itemId = Array.isArray(req.params.itemId) ? req.params.itemId[0] : req.params.itemId;
      const validated = updateMenuItemSchema.parse(req.body);
      const menuItem = await RestaurantService.updateMenuItem(
        req.user!.id,
        itemId,
        validated as any,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { menuItem });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.patch(
  '/restaurants/mine/menu-items/:itemId/toggle-availability',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const itemId = Array.isArray(req.params.itemId) ? req.params.itemId[0] : req.params.itemId;
      const validated = toggleAvailabilitySchema.parse(req.body);
      const menuItem = await RestaurantService.toggleItemAvailability(
        req.user!.id,
        itemId,
        validated.isAvailable
      );
      sendSuccess(res, { menuItem });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.delete(
  '/restaurants/mine/menu-items/:itemId',
  requireAuth,
  requireRoles('RESTAURANT_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const itemId = Array.isArray(req.params.itemId) ? req.params.itemId[0] : req.params.itemId;
      await RestaurantService.deleteMenuItem(
        req.user!.id,
        itemId,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { message: 'Menu item deleted successfully' });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * 4. SYSTEM ADMIN APPROVALS (SRS REST-2)
 */

restaurantRouter.get(
  '/restaurants/pending',
  requireAuth,
  requireRoles('SYSTEM_ADMIN'),
  async (_req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurants = await RestaurantService.listPendingRestaurants();
      sendSuccess(res, { restaurants });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.post(
  '/restaurants/:id/approve',
  requireAuth,
  requireRoles('SYSTEM_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurantId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const restaurant = await RestaurantService.approveRestaurant(
        req.user!.id,
        restaurantId,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { restaurant, message: 'Restaurant approved successfully' });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.post(
  '/restaurants/:id/reject',
  requireAuth,
  requireRoles('SYSTEM_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurantId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const validated = rejectSchema.parse(req.body);
      const restaurant = await RestaurantService.rejectRestaurant(
        req.user!.id,
        restaurantId,
        validated.reason,
        req.ip,
        req.get('user-agent')
      );
      sendSuccess(res, { restaurant, message: 'Restaurant registration rejected' });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.get(
  '/restaurants',
  requireAuth,
  requireRoles('SYSTEM_ADMIN'),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const status = req.query.status as string | undefined;
      const restaurants = await RestaurantService.listAllRestaurants(status);
      sendSuccess(res, { restaurants });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * 5. PUBLIC RESTAURANT & MENU READS
 */

restaurantRouter.get(
  '/restaurants/:id',
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurantId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const restaurant = await RestaurantService.getPublicRestaurant(restaurantId);
      sendSuccess(res, { restaurant });
    } catch (err) {
      next(err);
    }
  }
);

restaurantRouter.get(
  '/restaurants/:id/menu',
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const restaurantId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const restaurant = await RestaurantService.getPublicRestaurant(restaurantId);
      const categories = await RestaurantService.getCategories(restaurant.id);
      const menuItems = await RestaurantService.getMenuItems(restaurant.id, undefined, true);
      sendSuccess(res, {
        restaurant,
        categories,
        menuItems,
      });
    } catch (err) {
      next(err);
    }
  }
);

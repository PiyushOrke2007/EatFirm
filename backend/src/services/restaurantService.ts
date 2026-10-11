import { pool } from '../database/db.js';
import {
  ValidationError,
  NotFoundError,
  ConflictError,
  ForbiddenError,
} from '../middleware/errorHandler.js';
import { logAuditEvent } from './auditService.js';
import {
  Restaurant,
  OperatingHour,
  MenuCategory,
  MenuItem,
  OnboardRestaurantInput,
  UpdateRestaurantInput,
  OperatingHourInput,
  CreateCategoryInput,
  UpdateCategoryInput,
  CreateMenuItemInput,
  UpdateMenuItemInput,
  DayOfWeek,
} from '../models/restaurant.js';
import { toPaise, fromPaise } from '../utils/money.js';

const VALID_DAYS: DayOfWeek[] = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/;

function validateTimeFormat(time: string, fieldName: string): void {
  if (!TIME_REGEX.test(time)) {
    throw new ValidationError(`Field '${fieldName}' must be in valid 24-hour HH:MM format (e.g. 09:00, 22:30)`);
  }
}

export class RestaurantService {
  /**
   * Onboard a new restaurant for an authenticated RESTAURANT_ADMIN.
   * SRS REST-1: submits name, address, cuisine type, operating hours for approval.
   * SRS Section 6: requires food licence number.
   */
  static async onboardRestaurant(
    userId: string,
    input: OnboardRestaurantInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<Restaurant> {
    // 1. Verify user does not already have a registered restaurant
    const existing = await pool.query('SELECT id FROM restaurants WHERE owner_id = $1', [userId]);
    if (existing.rows.length > 0) {
      throw new ConflictError('A restaurant is already registered for this account');
    }

    // 2. Validate fields
    if (!input.name || input.name.trim().length < 2) {
      throw new ValidationError('Restaurant name must be at least 2 characters');
    }
    if (!input.address || input.address.trim().length < 5) {
      throw new ValidationError('Address must be at least 5 characters');
    }
    if (!input.phone || !/^\d{10}$/.test(input.phone)) {
      throw new ValidationError('Phone number must be a valid 10-digit number');
    }
    if (!input.cuisineType || input.cuisineType.trim().length < 2) {
      throw new ValidationError('Cuisine type is required');
    }
    if (!input.foodLicenseNumber || input.foodLicenseNumber.trim().length < 3) {
      throw new ValidationError('Food license number is required (FSSAI/Local regulation)');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const resResult = await client.query(
        `INSERT INTO restaurants (
          owner_id, name, description, address, phone, cuisine_type, food_license_number, image_url, approval_status, is_open
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'PENDING_APPROVAL', true)
        RETURNING *`,
        [
          userId,
          input.name.trim(),
          input.description?.trim() || null,
          input.address.trim(),
          input.phone.trim(),
          input.cuisineType.trim(),
          input.foodLicenseNumber.trim(),
          input.imageUrl?.trim() || null,
        ]
      );

      const restaurantRow = resResult.rows[0];

      // Insert operating hours
      const hoursToInsert =
        input.operatingHours && input.operatingHours.length > 0
          ? input.operatingHours
          : VALID_DAYS.map((day) => ({
              dayOfWeek: day,
              openTime: '09:00',
              closeTime: '22:00',
              isClosed: false,
            }));

      const insertedHours: OperatingHour[] = [];
      for (const h of hoursToInsert) {
        if (!VALID_DAYS.includes(h.dayOfWeek)) {
          throw new ValidationError(`Invalid day of week: ${h.dayOfWeek}`);
        }
        validateTimeFormat(h.openTime, 'openTime');
        validateTimeFormat(h.closeTime, 'closeTime');

        const hrResult = await client.query(
          `INSERT INTO operating_hours (restaurant_id, day_of_week, open_time, close_time, is_closed)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [restaurantRow.id, h.dayOfWeek, h.openTime, h.closeTime, h.isClosed ?? false]
        );
        insertedHours.push(this.mapOperatingHour(hrResult.rows[0]));
      }

      await client.query('COMMIT');

      await logAuditEvent({
        action: 'RESTAURANT_ONBOARDED',
        actorId: userId,
        actorRole: 'RESTAURANT_ADMIN',
        ipAddress,
        userAgent,
        details: {
          restaurantId: restaurantRow.id,
          name: restaurantRow.name,
          approvalStatus: restaurantRow.approval_status,
        },
      });

      return {
        ...this.mapRestaurant(restaurantRow),
        operatingHours: insertedHours,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Retrieves the current user's restaurant profile.
   */
  static async getMyRestaurant(userId: string): Promise<Restaurant | null> {
    const res = await pool.query('SELECT * FROM restaurants WHERE owner_id = $1', [userId]);
    if (res.rows.length === 0) {
      return null;
    }

    const restaurant = this.mapRestaurant(res.rows[0]);
    const hoursRes = await pool.query(
      'SELECT * FROM operating_hours WHERE restaurant_id = $1 ORDER BY id',
      [restaurant.id]
    );
    restaurant.operatingHours = hoursRes.rows.map(this.mapOperatingHour);
    return restaurant;
  }

  /**
   * Updates restaurant profile for authenticated owner.
   */
  static async updateRestaurantProfile(
    userId: string,
    input: UpdateRestaurantInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<Restaurant> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    if (input.phone && !/^\d{10}$/.test(input.phone)) {
      throw new ValidationError('Phone number must be a valid 10-digit number');
    }

    const res = await pool.query(
      `UPDATE restaurants
       SET name = COALESCE($1, name),
           description = COALESCE($2, description),
           address = COALESCE($3, address),
           phone = COALESCE($4, phone),
           cuisine_type = COALESCE($5, cuisine_type),
           food_license_number = COALESCE($6, food_license_number),
           image_url = COALESCE($7, image_url),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $8
       RETURNING *`,
      [
        input.name?.trim(),
        input.description !== undefined ? input.description.trim() || null : null,
        input.address?.trim(),
        input.phone?.trim(),
        input.cuisineType?.trim(),
        input.foodLicenseNumber?.trim(),
        input.imageUrl !== undefined ? input.imageUrl.trim() || null : null,
        myRes.id,
      ]
    );

    await logAuditEvent({
      action: 'RESTAURANT_PROFILE_UPDATED',
      actorId: userId,
      actorRole: 'RESTAURANT_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId: myRes.id },
    });

    const updated = this.mapRestaurant(res.rows[0]);
    const hours = await pool.query('SELECT * FROM operating_hours WHERE restaurant_id = $1', [myRes.id]);
    updated.operatingHours = hours.rows.map(this.mapOperatingHour);
    return updated;
  }

  /**
   * Toggles restaurant open/closed status (operational availability).
   */
  static async toggleRestaurantOpen(
    userId: string,
    isOpen: boolean,
    ipAddress?: string,
    userAgent?: string
  ): Promise<Restaurant> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const res = await pool.query(
      `UPDATE restaurants
       SET is_open = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [isOpen, myRes.id]
    );

    await logAuditEvent({
      action: 'RESTAURANT_AVAILABILITY_TOGGLED',
      actorId: userId,
      actorRole: 'RESTAURANT_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId: myRes.id, isOpen },
    });

    return this.mapRestaurant(res.rows[0]);
  }

  /**
   * Updates operating hours schedule for restaurant.
   */
  static async updateOperatingHours(
    userId: string,
    hours: OperatingHourInput[]
  ): Promise<OperatingHour[]> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const updatedHours: OperatingHour[] = [];
      for (const h of hours) {
        if (!VALID_DAYS.includes(h.dayOfWeek)) {
          throw new ValidationError(`Invalid day of week: ${h.dayOfWeek}`);
        }
        validateTimeFormat(h.openTime, 'openTime');
        validateTimeFormat(h.closeTime, 'closeTime');

        const res = await client.query(
          `INSERT INTO operating_hours (restaurant_id, day_of_week, open_time, close_time, is_closed, updated_at)
           VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
           ON CONFLICT (restaurant_id, day_of_week)
           DO UPDATE SET
             open_time = EXCLUDED.open_time,
             close_time = EXCLUDED.close_time,
             is_closed = EXCLUDED.is_closed,
             updated_at = CURRENT_TIMESTAMP
           RETURNING *`,
          [myRes.id, h.dayOfWeek, h.openTime, h.closeTime, h.isClosed ?? false]
        );
        updatedHours.push(this.mapOperatingHour(res.rows[0]));
      }

      await client.query('COMMIT');
      return updatedHours;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * System Administrator approves restaurant registration (SRS REST-2).
   */
  static async approveRestaurant(
    adminId: string,
    restaurantId: string,
    ipAddress?: string,
    userAgent?: string
  ): Promise<Restaurant> {
    const res = await pool.query(
      `UPDATE restaurants
       SET approval_status = 'APPROVED',
           rejection_reason = NULL,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [restaurantId]
    );

    if (res.rows.length === 0) {
      throw new NotFoundError('Restaurant not found');
    }

    await logAuditEvent({
      action: 'RESTAURANT_APPROVED',
      actorId: adminId,
      actorRole: 'SYSTEM_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId },
    });

    return this.mapRestaurant(res.rows[0]);
  }

  /**
   * System Administrator rejects restaurant registration (SRS REST-2).
   */
  static async rejectRestaurant(
    adminId: string,
    restaurantId: string,
    reason: string,
    ipAddress?: string,
    userAgent?: string
  ): Promise<Restaurant> {
    if (!reason || reason.trim().length < 3) {
      throw new ValidationError('A rejection reason of at least 3 characters is required');
    }

    const res = await pool.query(
      `UPDATE restaurants
       SET approval_status = 'REJECTED',
           rejection_reason = $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING *`,
      [reason.trim(), restaurantId]
    );

    if (res.rows.length === 0) {
      throw new NotFoundError('Restaurant not found');
    }

    await logAuditEvent({
      action: 'RESTAURANT_REJECTED',
      actorId: adminId,
      actorRole: 'SYSTEM_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId, reason: reason.trim() },
    });

    return this.mapRestaurant(res.rows[0]);
  }

  /**
   * System Administrator lists restaurants pending approval.
   */
  static async listPendingRestaurants(): Promise<Restaurant[]> {
    const res = await pool.query(
      `SELECT * FROM restaurants
       WHERE approval_status = 'PENDING_APPROVAL'
       ORDER BY created_at ASC`
    );
    return res.rows.map(this.mapRestaurant);
  }

  /**
   * Lists all restaurants with optional approval filter.
   */
  static async listAllRestaurants(approvalStatus?: string): Promise<Restaurant[]> {
    let query = 'SELECT * FROM restaurants';
    const params: any[] = [];
    if (approvalStatus) {
      query += ' WHERE approval_status = $1';
      params.push(approvalStatus);
    }
    query += ' ORDER BY created_at DESC';

    const res = await pool.query(query, params);
    return res.rows.map(this.mapRestaurant);
  }

  /**
   * CATEGORIES (SRS REST-3)
   */
  static async getCategories(restaurantId: string): Promise<MenuCategory[]> {
    const res = await pool.query(
      `SELECT c.*, COUNT(m.id)::int AS item_count
       FROM menu_categories c
       LEFT JOIN menu_items m ON m.category_id = c.id
       WHERE c.restaurant_id = $1
       GROUP BY c.id
       ORDER BY c.sort_order ASC, c.name ASC`,
      [restaurantId]
    );
    return res.rows.map(this.mapMenuCategory);
  }

  static async createCategory(userId: string, input: CreateCategoryInput): Promise<MenuCategory> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    if (!input.name || input.name.trim().length < 1) {
      throw new ValidationError('Category name is required');
    }

    const existing = await pool.query(
      'SELECT id FROM menu_categories WHERE restaurant_id = $1 AND LOWER(name) = LOWER($2)',
      [myRes.id, input.name.trim()]
    );
    if (existing.rows.length > 0) {
      throw new ConflictError(`Category '${input.name.trim()}' already exists`);
    }

    const res = await pool.query(
      `INSERT INTO menu_categories (restaurant_id, name, sort_order)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [myRes.id, input.name.trim(), input.sortOrder ?? 0]
    );

    return this.mapMenuCategory(res.rows[0]);
  }

  static async updateCategory(
    userId: string,
    categoryId: string,
    input: UpdateCategoryInput
  ): Promise<MenuCategory> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const catCheck = await pool.query(
      'SELECT id FROM menu_categories WHERE id = $1 AND restaurant_id = $2',
      [categoryId, myRes.id]
    );
    if (catCheck.rows.length === 0) {
      throw new NotFoundError('Category not found or does not belong to your restaurant');
    }

    if (input.name) {
      const dupCheck = await pool.query(
        'SELECT id FROM menu_categories WHERE restaurant_id = $1 AND LOWER(name) = LOWER($2) AND id != $3',
        [myRes.id, input.name.trim(), categoryId]
      );
      if (dupCheck.rows.length > 0) {
        throw new ConflictError(`Category '${input.name.trim()}' already exists`);
      }
    }

    const res = await pool.query(
      `UPDATE menu_categories
       SET name = COALESCE($1, name),
           sort_order = COALESCE($2, sort_order),
           is_active = COALESCE($3, is_active),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING *`,
      [
        input.name?.trim(),
        input.sortOrder,
        input.isActive,
        categoryId,
      ]
    );

    return this.mapMenuCategory(res.rows[0]);
  }

  static async deleteCategory(userId: string, categoryId: string): Promise<void> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const catCheck = await pool.query(
      'SELECT id FROM menu_categories WHERE id = $1 AND restaurant_id = $2',
      [categoryId, myRes.id]
    );
    if (catCheck.rows.length === 0) {
      throw new NotFoundError('Category not found or does not belong to your restaurant');
    }

    const itemsCheck = await pool.query(
      'SELECT id FROM menu_items WHERE category_id = $1 LIMIT 1',
      [categoryId]
    );
    if (itemsCheck.rows.length > 0) {
      throw new ValidationError(
        'Cannot delete category containing menu items. Please remove or reassign the items first.'
      );
    }

    await pool.query('DELETE FROM menu_categories WHERE id = $1', [categoryId]);
  }

  /**
   * MENU ITEMS (SRS REST-3, REST-4, REST-5, REST-6, NFR-12)
   */
  static async getMenuItems(
    restaurantId: string,
    categoryId?: string,
    isAvailableOnly?: boolean
  ): Promise<MenuItem[]> {
    let query = `
      SELECT m.*, c.name AS category_name
      FROM menu_items m
      JOIN menu_categories c ON c.id = m.category_id
      WHERE m.restaurant_id = $1
    `;
    const params: any[] = [restaurantId];

    if (categoryId) {
      params.push(categoryId);
      query += ` AND m.category_id = $${params.length}`;
    }

    if (isAvailableOnly) {
      query += ' AND m.is_available = true';
    }

    query += ' ORDER BY c.sort_order ASC, m.name ASC';

    const res = await pool.query(query, params);
    return res.rows.map(this.mapMenuItem);
  }

  static async createMenuItem(
    userId: string,
    input: CreateMenuItemInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<MenuItem> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    // Verify category belongs to this restaurant
    const catCheck = await pool.query(
      'SELECT id, name FROM menu_categories WHERE id = $1 AND restaurant_id = $2',
      [input.categoryId, myRes.id]
    );
    if (catCheck.rows.length === 0) {
      throw new ValidationError('Invalid category for this restaurant');
    }

    if (!input.name || input.name.trim().length < 1) {
      throw new ValidationError('Item name is required');
    }

    const priceNum = typeof input.price === 'string' ? parseFloat(input.price) : input.price;
    if (isNaN(priceNum) || priceNum < 0) {
      throw new ValidationError('Price must be a non-negative number');
    }
    const formattedPrice = fromPaise(toPaise(priceNum));

    // Special offer validations (REST-6)
    let formattedOfferPrice: string | null = null;
    const isSpecial = input.isSpecialOffer ?? false;
    if (isSpecial) {
      if (input.offerPrice === undefined || input.offerPrice === null) {
        throw new ValidationError('Special offer items require a valid offerPrice');
      }
      const offerNum = typeof input.offerPrice === 'string' ? parseFloat(input.offerPrice) : input.offerPrice;
      if (isNaN(offerNum) || offerNum < 0) {
        throw new ValidationError('Offer price must be a non-negative number');
      }
      if (offerNum >= priceNum) {
        throw new ValidationError('Offer price must be strictly less than original price');
      }
      formattedOfferPrice = fromPaise(toPaise(offerNum));
    }

    // Time-based availability validations (REST-5)
    if (input.availableFrom) {
      validateTimeFormat(input.availableFrom, 'availableFrom');
    }
    if (input.availableUntil) {
      validateTimeFormat(input.availableUntil, 'availableUntil');
    }

    const res = await pool.query(
      `INSERT INTO menu_items (
        restaurant_id, category_id, name, description, price, is_veg, image_url,
        is_available, available_from, available_until, is_special_offer, offer_price
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *`,
      [
        myRes.id,
        input.categoryId,
        input.name.trim(),
        input.description?.trim() || null,
        formattedPrice,
        input.isVeg ?? true,
        input.imageUrl?.trim() || null,
        input.isAvailable ?? true,
        input.availableFrom?.trim() || null,
        input.availableUntil?.trim() || null,
        isSpecial,
        formattedOfferPrice,
      ]
    );

    await logAuditEvent({
      action: 'MENU_ITEM_CREATED',
      actorId: userId,
      actorRole: 'RESTAURANT_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId: myRes.id, itemId: res.rows[0].id, name: input.name.trim() },
    });

    const item = this.mapMenuItem(res.rows[0]);
    item.categoryName = catCheck.rows[0].name;
    return item;
  }

  static async updateMenuItem(
    userId: string,
    itemId: string,
    input: UpdateMenuItemInput,
    ipAddress?: string,
    userAgent?: string
  ): Promise<MenuItem> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const itemRes = await pool.query(
      'SELECT * FROM menu_items WHERE id = $1 AND restaurant_id = $2',
      [itemId, myRes.id]
    );
    if (itemRes.rows.length === 0) {
      throw new NotFoundError('Menu item not found or does not belong to your restaurant');
    }
    const current = itemRes.rows[0];

    // If category is changing, check ownership
    let categoryName = current.category_name;
    if (input.categoryId && input.categoryId !== current.category_id) {
      const catCheck = await pool.query(
        'SELECT id, name FROM menu_categories WHERE id = $1 AND restaurant_id = $2',
        [input.categoryId, myRes.id]
      );
      if (catCheck.rows.length === 0) {
        throw new ValidationError('Invalid category for this restaurant');
      }
      categoryName = catCheck.rows[0].name;
    }

    const targetPrice =
      input.price !== undefined
        ? typeof input.price === 'string'
          ? parseFloat(input.price)
          : input.price
        : parseFloat(current.price);

    if (isNaN(targetPrice) || targetPrice < 0) {
      throw new ValidationError('Price must be a non-negative number');
    }
    const formattedPrice = fromPaise(toPaise(targetPrice));

    const isSpecial = input.isSpecialOffer !== undefined ? input.isSpecialOffer : current.is_special_offer;
    let formattedOfferPrice: string | null = null;
    if (isSpecial) {
      const rawOffer = input.offerPrice !== undefined ? input.offerPrice : current.offer_price;
      if (rawOffer === null || rawOffer === undefined) {
        throw new ValidationError('Special offer items require a valid offerPrice');
      }
      const offerNum = typeof rawOffer === 'string' ? parseFloat(rawOffer) : rawOffer;
      if (isNaN(offerNum) || offerNum < 0) {
        throw new ValidationError('Offer price must be a non-negative number');
      }
      if (offerNum >= targetPrice) {
        throw new ValidationError('Offer price must be strictly less than original price');
      }
      formattedOfferPrice = fromPaise(toPaise(offerNum));
    }

    if (input.availableFrom) {
      validateTimeFormat(input.availableFrom, 'availableFrom');
    }
    if (input.availableUntil) {
      validateTimeFormat(input.availableUntil, 'availableUntil');
    }

    const res = await pool.query(
      `UPDATE menu_items
       SET category_id = COALESCE($1, category_id),
           name = COALESCE($2, name),
           description = COALESCE($3, description),
           price = $4,
           is_veg = COALESCE($5, is_veg),
           image_url = COALESCE($6, image_url),
           is_available = COALESCE($7, is_available),
           available_from = $8,
           available_until = $9,
           is_special_offer = $10,
           offer_price = $11,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $12
       RETURNING *`,
      [
        input.categoryId,
        input.name?.trim(),
        input.description !== undefined ? input.description.trim() || null : current.description,
        formattedPrice,
        input.isVeg,
        input.imageUrl !== undefined ? input.imageUrl.trim() || null : current.image_url,
        input.isAvailable,
        input.availableFrom !== undefined ? input.availableFrom?.trim() || null : current.available_from,
        input.availableUntil !== undefined ? input.availableUntil?.trim() || null : current.available_until,
        isSpecial,
        formattedOfferPrice,
        itemId,
      ]
    );

    await logAuditEvent({
      action: 'MENU_ITEM_UPDATED',
      actorId: userId,
      actorRole: 'RESTAURANT_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId: myRes.id, itemId },
    });

    const updated = this.mapMenuItem(res.rows[0]);
    updated.categoryName = categoryName;
    return updated;
  }

  /**
   * Temporary availability toggle (REST-4).
   */
  static async toggleItemAvailability(
    userId: string,
    itemId: string,
    isAvailable: boolean
  ): Promise<MenuItem> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const res = await pool.query(
      `UPDATE menu_items
       SET is_available = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND restaurant_id = $3
       RETURNING *`,
      [isAvailable, itemId, myRes.id]
    );

    if (res.rows.length === 0) {
      throw new NotFoundError('Menu item not found or does not belong to your restaurant');
    }

    return this.mapMenuItem(res.rows[0]);
  }

  /**
   * Delete menu item with confirmation requirement (NFR-14).
   */
  static async deleteMenuItem(
    userId: string,
    itemId: string,
    ipAddress?: string,
    userAgent?: string
  ): Promise<void> {
    const myRes = await this.getMyRestaurant(userId);
    if (!myRes) {
      throw new NotFoundError('No restaurant found for this account');
    }

    const res = await pool.query(
      'DELETE FROM menu_items WHERE id = $1 AND restaurant_id = $2 RETURNING id, name',
      [itemId, myRes.id]
    );

    if (res.rows.length === 0) {
      throw new NotFoundError('Menu item not found or does not belong to your restaurant');
    }

    await logAuditEvent({
      action: 'MENU_ITEM_DELETED',
      actorId: userId,
      actorRole: 'RESTAURANT_ADMIN',
      ipAddress,
      userAgent,
      details: { restaurantId: myRes.id, itemId, name: res.rows[0].name },
    });
  }

  /**
   * Public Restaurant Details (Only approved restaurants, or owner/admin).
   */
  static async getPublicRestaurant(restaurantId: string): Promise<Restaurant> {
    const res = await pool.query('SELECT * FROM restaurants WHERE id = $1', [restaurantId]);
    if (res.rows.length === 0) {
      throw new NotFoundError('Restaurant not found');
    }
    const r = this.mapRestaurant(res.rows[0]);
    const hours = await pool.query(
      'SELECT * FROM operating_hours WHERE restaurant_id = $1 ORDER BY id',
      [restaurantId]
    );
    r.operatingHours = hours.rows.map(this.mapOperatingHour);
    return r;
  }

  // --- Helper mappers ---
  private static mapRestaurant(row: any): Restaurant {
    return {
      id: row.id,
      ownerId: row.owner_id,
      name: row.name,
      description: row.description,
      address: row.address,
      phone: row.phone,
      cuisineType: row.cuisine_type,
      foodLicenseNumber: row.food_license_number,
      imageUrl: row.image_url,
      approvalStatus: row.approval_status,
      rejectionReason: row.rejection_reason,
      isOpen: row.is_open,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }

  private static mapOperatingHour(row: any): OperatingHour {
    return {
      id: row.id,
      restaurantId: row.restaurant_id,
      dayOfWeek: row.day_of_week,
      openTime: row.open_time,
      closeTime: row.close_time,
      isClosed: row.is_closed,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }

  private static mapMenuCategory(row: any): MenuCategory {
    return {
      id: row.id,
      restaurantId: row.restaurant_id,
      name: row.name,
      sortOrder: row.sort_order,
      isActive: row.is_active,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
      itemCount: row.item_count !== undefined ? Number(row.item_count) : undefined,
    };
  }

  private static mapMenuItem(row: any): MenuItem {
    return {
      id: row.id,
      restaurantId: row.restaurant_id,
      categoryId: row.category_id,
      categoryName: row.category_name,
      name: row.name,
      description: row.description,
      price: row.price,
      isVeg: row.is_veg,
      imageUrl: row.image_url,
      isAvailable: row.is_available,
      availableFrom: row.available_from,
      availableUntil: row.available_until,
      isSpecialOffer: row.is_special_offer,
      offerPrice: row.offer_price,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString(),
    };
  }
}


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
  BrowseRestaurantsQuery,
  SearchSuggestion,
  CustomerRestaurantDetails,
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

  /**
   * BROWSE-1 & BROWSE-2: Customer Restaurant Listing with Search, Filters, and Sorting.
   */
  static async browseRestaurants(filters: BrowseRestaurantsQuery): Promise<{
    restaurants: Restaurant[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const page = Math.max(1, filters.page ?? 1);
    const limit = Math.min(50, Math.max(1, filters.limit ?? 20));
    const offset = (page - 1) * limit;

    const hasCoords =
      filters.latitude !== undefined &&
      filters.longitude !== undefined &&
      !isNaN(filters.latitude) &&
      !isNaN(filters.longitude);

    let distanceExpr = 'NULL::numeric AS distance_km';
    if (hasCoords) {
      distanceExpr = `ROUND((
        6371 * acos(
          LEAST(1.0, GREATEST(-1.0,
            cos(radians(${Number(filters.latitude)})) *
            cos(radians(r.latitude)) *
            cos(radians(r.longitude) - radians(${Number(filters.longitude)})) +
            sin(radians(${Number(filters.latitude)})) *
            sin(radians(r.latitude))
          ))
        )
      )::numeric, 1) AS distance_km`;
    }

    const conditions: string[] = ["r.approval_status = 'APPROVED'"];
    const params: any[] = [];
    let paramIndex = 1;

    if (filters.isOpenOnly) {
      conditions.push('r.is_open = true');
    }

    if (filters.cuisine && filters.cuisine.trim().length > 0) {
      conditions.push(`r.cuisine_type ILIKE $${paramIndex}`);
      params.push(`%${filters.cuisine.trim()}%`);
      paramIndex++;
    }

    if (filters.priceTier && filters.priceTier.trim().length > 0) {
      conditions.push(`r.price_tier = $${paramIndex}`);
      params.push(filters.priceTier.trim());
      paramIndex++;
    }

    if (filters.minRating !== undefined && filters.minRating > 0) {
      conditions.push(`r.average_rating >= $${paramIndex}`);
      params.push(filters.minRating);
      paramIndex++;
    }

    if (filters.vegOnly) {
      conditions.push(`EXISTS (
        SELECT 1 FROM menu_items mi
        WHERE mi.restaurant_id = r.id AND mi.is_veg = true AND mi.is_available = true
      )`);
    }

    if (filters.search && filters.search.trim().length > 0) {
      const q = `%${filters.search.trim()}%`;
      conditions.push(`(
        r.name ILIKE $${paramIndex} OR
        r.cuisine_type ILIKE $${paramIndex} OR
        EXISTS (
          SELECT 1 FROM menu_items mi
          WHERE mi.restaurant_id = r.id AND mi.name ILIKE $${paramIndex}
        )
      )`);
      params.push(q);
      paramIndex++;
    }

    const whereClause = conditions.join(' AND ');

    let orderBy = 'is_open DESC, average_rating DESC NULLS LAST, created_at DESC';
    switch (filters.sortBy) {
      case 'rating_desc':
        orderBy = 'average_rating DESC NULLS LAST, rating_count DESC';
        break;
      case 'distance_asc':
        orderBy = hasCoords ? 'distance_km ASC NULLS LAST' : 'created_at DESC';
        break;
      case 'delivery_time_asc':
        orderBy = 'estimated_delivery_mins ASC';
        break;
      case 'cost_low_to_high':
        orderBy = 'price_tier ASC, name ASC';
        break;
      case 'cost_high_to_low':
        orderBy = 'price_tier DESC, name ASC';
        break;
      case 'relevance':
      default:
        orderBy = hasCoords
          ? 'is_open DESC, distance_km ASC NULLS LAST, average_rating DESC NULLS LAST'
          : 'is_open DESC, average_rating DESC NULLS LAST, created_at DESC';
        break;
    }

    const baseQuery = `
      SELECT r.*, ${distanceExpr}
      FROM restaurants r
      WHERE ${whereClause}
    `;

    let finalQuery = `WITH scored_restaurants AS (${baseQuery}) SELECT * FROM scored_restaurants`;
    const postConditions: string[] = [];

    if (hasCoords && filters.maxDistanceKm !== undefined && filters.maxDistanceKm > 0) {
      postConditions.push(`distance_km <= $${paramIndex}`);
      params.push(filters.maxDistanceKm);
      paramIndex++;
    }

    if (filters.maxDeliveryMins !== undefined && filters.maxDeliveryMins > 0) {
      postConditions.push(`estimated_delivery_mins <= $${paramIndex}`);
      params.push(filters.maxDeliveryMins);
      paramIndex++;
    }

    if (postConditions.length > 0) {
      finalQuery += ` WHERE ${postConditions.join(' AND ')}`;
    }

    // Count query
    const countSql = `SELECT COUNT(*) AS total FROM (${finalQuery}) count_alias`;
    const countRes = await pool.query(countSql, params);
    const total = parseInt(countRes.rows[0].total, 10) || 0;

    // Paged query
    const pagedSql = `${finalQuery} ORDER BY ${orderBy} LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    const pagedParams = [...params, limit, offset];
    const dataRes = await pool.query(pagedSql, pagedParams);

    const restaurants = dataRes.rows.map(this.mapRestaurant);

    return {
      restaurants,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /**
   * Fast Search Suggestions (SRS NFR-4: < 2s).
   */
  static async getSearchSuggestions(query: string): Promise<SearchSuggestion[]> {
    if (!query || query.trim().length === 0) {
      return [];
    }

    const term = `%${query.trim()}%`;
    const suggestions: SearchSuggestion[] = [];

    // 1. Restaurant names
    const restRes = await pool.query(
      `SELECT id, name, cuisine_type FROM restaurants
       WHERE approval_status = 'APPROVED' AND name ILIKE $1
       ORDER BY average_rating DESC NULLS LAST
       LIMIT 4`,
      [term]
    );
    for (const row of restRes.rows) {
      suggestions.push({
        type: 'restaurant',
        text: row.name,
        subtext: row.cuisine_type,
        id: row.id,
      });
    }

    // 2. Dish names
    const itemRes = await pool.query(
      `SELECT mi.name, mi.is_veg, r.name AS restaurant_name, r.id AS restaurant_id
       FROM menu_items mi
       JOIN restaurants r ON mi.restaurant_id = r.id
       WHERE r.approval_status = 'APPROVED' AND mi.is_available = true AND mi.name ILIKE $1
       LIMIT 4`,
      [term]
    );
    for (const row of itemRes.rows) {
      suggestions.push({
        type: 'dish',
        text: row.name,
        subtext: `${row.is_veg ? 'Veg' : 'Non-Veg'} • ${row.restaurant_name}`,
        id: row.restaurant_id,
      });
    }

    // 3. Cuisines
    const cuisineRes = await pool.query(
      `SELECT DISTINCT cuisine_type FROM restaurants
       WHERE approval_status = 'APPROVED' AND cuisine_type ILIKE $1
       LIMIT 3`,
      [term]
    );
    for (const row of cuisineRes.rows) {
      suggestions.push({
        type: 'cuisine',
        text: row.cuisine_type,
        subtext: 'Cuisine',
      });
    }

    return suggestions;
  }

  /**
   * Customer Restaurant Menu with Category & Veg Filter (SRS BROWSE-3, NFR-12).
   */
  static async getCustomerRestaurantMenu(
    restaurantId: string,
    filters?: { categoryId?: string; isVeg?: boolean; search?: string }
  ): Promise<{
    restaurant: Restaurant;
    categories: (MenuCategory & { items: MenuItem[] })[];
    menuItems?: MenuItem[];
  }> {
    const restaurant = await this.getPublicRestaurant(restaurantId);

    // Fetch active categories
    const catRes = await pool.query(
      `SELECT * FROM menu_categories
       WHERE restaurant_id = $1 AND is_active = true
       ORDER BY sort_order ASC, name ASC`,
      [restaurantId]
    );

    let itemQuery = `
      SELECT mi.*, mc.name AS category_name
      FROM menu_items mi
      JOIN menu_categories mc ON mi.category_id = mc.id
      WHERE mi.restaurant_id = $1
    `;
    const params: any[] = [restaurantId];
    let pIdx = 2;

    if (filters?.categoryId) {
      itemQuery += ` AND mi.category_id = $${pIdx}`;
      params.push(filters.categoryId);
      pIdx++;
    }

    if (filters?.isVeg !== undefined) {
      itemQuery += ` AND mi.is_veg = $${pIdx}`;
      params.push(filters.isVeg);
      pIdx++;
    }

    if (filters?.search && filters.search.trim().length > 0) {
      itemQuery += ` AND mi.name ILIKE $${pIdx}`;
      params.push(`%${filters.search.trim()}%`);
      pIdx++;
    }

    itemQuery += ` ORDER BY mi.is_special_offer DESC, mi.name ASC`;

    const itemRes = await pool.query(itemQuery, params);
    const items = itemRes.rows.map(this.mapMenuItem);

    // Group items under categories
    const categoriesWithItems = catRes.rows.map((catRow) => {
      const cat = this.mapMenuCategory(catRow);
      const catItems = items.filter((item) => item.categoryId === cat.id);
      return {
        ...cat,
        items: catItems,
      };
    });

    return {
      restaurant,
      categories: categoriesWithItems,
      menuItems: items,
    };
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
      latitude: row.latitude !== null && row.latitude !== undefined ? Number(row.latitude) : undefined,
      longitude: row.longitude !== null && row.longitude !== undefined ? Number(row.longitude) : undefined,
      averageRating: row.average_rating !== null && row.average_rating !== undefined ? Number(row.average_rating) : null,
      ratingCount: row.rating_count !== null && row.rating_count !== undefined ? Number(row.rating_count) : 0,
      estimatedDeliveryMins: row.estimated_delivery_mins !== null && row.estimated_delivery_mins !== undefined ? Number(row.estimated_delivery_mins) : 30,
      priceTier: row.price_tier ?? '₹₹',
      distanceKm: row.distance_km !== null && row.distance_km !== undefined ? Number(Number(row.distance_km).toFixed(1)) : undefined,
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


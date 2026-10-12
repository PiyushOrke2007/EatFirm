import { pool } from '../database/db.js';
import {
  ValidationError,
  NotFoundError,
  AppError,
} from '../middleware/errorHandler.js';
import {
  CartModel,
  CartItemModel,
  AddToCartInput,
  UpdateCartItemInput,
  UpdateCartNotesInput,
} from '../models/cart.js';
import { toPaise, fromPaise } from '../utils/money.js';

export class CartRestaurantConflictError extends AppError {
  public readonly existingRestaurantId: string;
  public readonly existingRestaurantName: string;

  constructor(existingRestaurantId: string, existingRestaurantName: string) {
    super(
      `Your cart contains items from ${existingRestaurantName}. Discard previous selection to add from this restaurant?`,
      409,
      'DIFFERENT_RESTAURANT_CONFLICT',
      [
        {
          field: 'restaurantId',
          message: `Cart is attached to ${existingRestaurantName} (${existingRestaurantId})`,
        },
      ]
    );
    this.existingRestaurantId = existingRestaurantId;
    this.existingRestaurantName = existingRestaurantName;
  }
}

export class CartService {
  /**
   * Helper: Recalculates financial totals for a cart given its items and restaurant.
   * Standard delivery fee: ₹30.00. Free if subtotal >= ₹500.00.
   * Tax: 5.0% GST on food subtotal (India standard).
   */
  private static calculateCartTotals(items: CartItemModel[]) {
    let subtotalPaise = 0;
    let itemCount = 0;

    for (const item of items) {
      subtotalPaise += toPaise(item.lineTotal);
      itemCount += item.quantity;
    }

    const deliveryFeePaise = items.length === 0 ? 0 : subtotalPaise >= 50000 ? 0 : 3000;
    const taxPaise = items.length === 0 ? 0 : Math.round(subtotalPaise * 0.05);
    const discountPaise = 0;
    const totalPaise = subtotalPaise + deliveryFeePaise + taxPaise - discountPaise;

    return {
      subtotal: fromPaise(subtotalPaise),
      deliveryFee: fromPaise(deliveryFeePaise),
      taxAmount: fromPaise(taxPaise),
      discountAmount: fromPaise(discountPaise),
      totalAmount: fromPaise(Math.max(0, totalPaise)),
      itemCount,
    };
  }

  /**
   * Retrieves the current user's active cart with populated items, menu metadata, and live financial breakdown.
   */
  static async getCart(userId: string): Promise<CartModel | null> {
    const cartRes = await pool.query(
      `SELECT c.id, c.customer_id, c.restaurant_id, c.special_instructions, c.created_at, c.updated_at,
              r.name as restaurant_name, r.address as restaurant_address
       FROM carts c
       JOIN restaurants r ON c.restaurant_id = r.id
       WHERE c.customer_id = $1`,
      [userId]
    );

    if (cartRes.rows.length === 0) {
      return null;
    }

    const cartRow = cartRes.rows[0];

    const itemsRes = await pool.query(
      `SELECT ci.id, ci.cart_id, ci.menu_item_id, ci.quantity, ci.item_instructions,
              ci.created_at, ci.updated_at,
              m.name, m.description, m.price, m.is_veg, m.is_available, m.image_url,
              m.is_special_offer, m.offer_price
       FROM cart_items ci
       JOIN menu_items m ON ci.menu_item_id = m.id
       WHERE ci.cart_id = $1
       ORDER BY ci.created_at ASC`,
      [cartRow.id]
    );

    // If all items were removed or don't exist, cleanup empty cart
    if (itemsRes.rows.length === 0) {
      await pool.query('DELETE FROM carts WHERE id = $1', [cartRow.id]);
      return null;
    }

    const items: CartItemModel[] = itemsRes.rows.map((row) => {
      const isOffer = row.is_special_offer && row.offer_price !== null;
      const unitPriceStr = isOffer ? row.offer_price : row.price;
      const unitPricePaise = toPaise(unitPriceStr);
      const lineTotalPaise = unitPricePaise * row.quantity;

      return {
        id: row.id,
        cartId: row.cart_id,
        menuItemId: row.menu_item_id,
        quantity: row.quantity,
        itemInstructions: row.item_instructions,
        name: row.name,
        description: row.description,
        price: row.price,
        effectivePrice: unitPriceStr,
        isVeg: row.is_veg,
        isAvailable: row.is_available,
        imageUrl: row.image_url,
        lineTotal: fromPaise(lineTotalPaise),
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString(),
      };
    });

    const totals = this.calculateCartTotals(items);

    return {
      id: cartRow.id,
      customerId: cartRow.customer_id,
      restaurantId: cartRow.restaurant_id,
      restaurantName: cartRow.restaurant_name,
      restaurantAddress: cartRow.restaurant_address,
      specialInstructions: cartRow.special_instructions,
      items,
      itemCount: totals.itemCount,
      subtotal: totals.subtotal,
      deliveryFee: totals.deliveryFee,
      taxAmount: totals.taxAmount,
      discountAmount: totals.discountAmount,
      totalAmount: totals.totalAmount,
      createdAt: cartRow.created_at.toISOString(),
      updatedAt: cartRow.updated_at.toISOString(),
    };
  }

  /**
   * Adds an item to the user's cart.
   * Enforces single-restaurant boundary (SRS ORD-02) and item availability.
   */
  static async addToCart(userId: string, input: AddToCartInput): Promise<CartModel> {
    const { restaurantId, menuItemId, quantity, itemInstructions, replaceCart } = input;

    if (!quantity || quantity <= 0) {
      throw new ValidationError('Quantity must be greater than zero');
    }
    if (quantity > 99) {
      throw new ValidationError('Quantity cannot exceed 99 items per dish');
    }

    // 1. Verify menu item exists, belongs to the restaurant, and is available
    const itemRes = await pool.query(
      `SELECT id, restaurant_id, name, is_available
       FROM menu_items
       WHERE id = $1`,
      [menuItemId]
    );

    if (itemRes.rows.length === 0) {
      throw new NotFoundError('Menu item does not exist');
    }

    const menuItem = itemRes.rows[0];
    if (menuItem.restaurant_id !== restaurantId) {
      throw new ValidationError('Menu item does not belong to the selected restaurant');
    }

    if (!menuItem.is_available) {
      throw new ValidationError(`"${menuItem.name}" is currently unavailable`);
    }

    // 2. Check current cart for the user
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const existingCartRes = await client.query(
        `SELECT c.id, c.restaurant_id, r.name as restaurant_name
         FROM carts c
         JOIN restaurants r ON c.restaurant_id = r.id
         WHERE c.customer_id = $1
         FOR UPDATE`,
        [userId]
      );

      let cartId: string;

      if (existingCartRes.rows.length > 0) {
        const existingCart = existingCartRes.rows[0];

        if (existingCart.restaurant_id !== restaurantId) {
          if (!replaceCart) {
            await client.query('ROLLBACK');
            throw new CartRestaurantConflictError(
              existingCart.restaurant_id,
              existingCart.restaurant_name
            );
          }

          // User explicitly agreed to replace items from the other restaurant
          await client.query('DELETE FROM carts WHERE id = $1', [existingCart.id]);
          const newCartRes = await client.query(
            `INSERT INTO carts (customer_id, restaurant_id)
             VALUES ($1, $2)
             RETURNING id`,
            [userId, restaurantId]
          );
          cartId = newCartRes.rows[0].id;
        } else {
          cartId = existingCart.id;
        }
      } else {
        // Create new cart
        const newCartRes = await client.query(
          `INSERT INTO carts (customer_id, restaurant_id)
           VALUES ($1, $2)
           RETURNING id`,
          [userId, restaurantId]
        );
        cartId = newCartRes.rows[0].id;
      }

      // 3. Add or update item in cart
      const existingItemRes = await client.query(
        `SELECT id, quantity FROM cart_items WHERE cart_id = $1 AND menu_item_id = $2`,
        [cartId, menuItemId]
      );

      if (existingItemRes.rows.length > 0) {
        const currentQty = existingItemRes.rows[0].quantity;
        const newQty = Math.min(99, currentQty + quantity);
        await client.query(
          `UPDATE cart_items
           SET quantity = $1, item_instructions = COALESCE($2, item_instructions), updated_at = CURRENT_TIMESTAMP
           WHERE id = $3`,
          [newQty, itemInstructions ?? null, existingItemRes.rows[0].id]
        );
      } else {
        await client.query(
          `INSERT INTO cart_items (cart_id, menu_item_id, quantity, item_instructions)
           VALUES ($1, $2, $3, $4)`,
          [cartId, menuItemId, quantity, itemInstructions ?? null]
        );
      }

      await client.query(
        `UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
        [cartId]
      );

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    const updatedCart = await this.getCart(userId);
    if (!updatedCart) {
      throw new AppError('Failed to retrieve cart after adding item');
    }
    return updatedCart;
  }

  /**
   * Updates the quantity or special instructions of a specific cart item.
   * If quantity <= 0, the item is removed.
   */
  static async updateCartItem(
    userId: string,
    cartItemId: string,
    input: UpdateCartItemInput
  ): Promise<CartModel | null> {
    const { quantity, itemInstructions } = input;

    if (quantity > 99) {
      throw new ValidationError('Quantity cannot exceed 99 items per dish');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const itemRes = await client.query(
        `SELECT ci.id, ci.cart_id, c.customer_id
         FROM cart_items ci
         JOIN carts c ON ci.cart_id = c.id
         WHERE ci.id = $1
         FOR UPDATE`,
        [cartItemId]
      );

      if (itemRes.rows.length === 0) {
        await client.query('ROLLBACK');
        throw new NotFoundError('Cart item not found');
      }

      if (itemRes.rows[0].customer_id !== userId) {
        await client.query('ROLLBACK');
        throw new ValidationError('You do not own this cart item');
      }

      const cartId = itemRes.rows[0].cart_id;

      if (quantity <= 0) {
        await client.query('DELETE FROM cart_items WHERE id = $1', [cartItemId]);
      } else {
        await client.query(
          `UPDATE cart_items
           SET quantity = $1,
               item_instructions = CASE WHEN $2::text IS NOT NULL THEN $2 ELSE item_instructions END,
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $3`,
          [quantity, itemInstructions !== undefined ? itemInstructions : null, cartItemId]
        );
      }

      // Check if cart has remaining items
      const remainingRes = await client.query(
        `SELECT COUNT(*) as count FROM cart_items WHERE cart_id = $1`,
        [cartId]
      );

      if (parseInt(remainingRes.rows[0].count, 10) === 0) {
        await client.query('DELETE FROM carts WHERE id = $1', [cartId]);
      } else {
        await client.query(
          `UPDATE carts SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
          [cartId]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    return this.getCart(userId);
  }

  /**
   * Removes an item from the cart.
   */
  static async removeCartItem(userId: string, cartItemId: string): Promise<CartModel | null> {
    return this.updateCartItem(userId, cartItemId, { quantity: 0 });
  }

  /**
   * Updates overall special cooking instructions for the cart (SRS CART-2).
   */
  static async updateCartNotes(userId: string, input: UpdateCartNotesInput): Promise<CartModel> {
    const res = await pool.query(
      `UPDATE carts
       SET special_instructions = $1, updated_at = CURRENT_TIMESTAMP
       WHERE customer_id = $2
       RETURNING id`,
      [input.specialInstructions ?? null, userId]
    );

    if (res.rows.length === 0) {
      throw new NotFoundError('Active cart not found');
    }

    const updated = await this.getCart(userId);
    if (!updated) {
      throw new AppError('Active cart is empty');
    }
    return updated;
  }

  /**
   * Clears the user's active cart.
   */
  static async clearCart(userId: string): Promise<void> {
    await pool.query('DELETE FROM carts WHERE customer_id = $1', [userId]);
  }
}


-- Module 05: Cart, Checkout, Order Placement, Order History, and Cancellation
-- Migration 005_cart_order.sql
-- Enforces SRS CART-1, CART-2, ORDER-1, ORDER-3, ORDER-4, NFR-12, NFR-13, NFR-14, NFR-16, Section 6

-- 1. Carts table (Customer active cart, single-restaurant boundary)
CREATE TABLE IF NOT EXISTS carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  special_instructions TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Cart Items table
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity > 0 AND quantity <= 99),
  item_instructions TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_cart_items_cart_menu_item UNIQUE (cart_id, menu_item_id)
);

-- 3. Orders table (Authoritative order record, financial totals, immutable snapshots)
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_order_number VARCHAR(30) UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE RESTRICT,
  delivery_address_snapshot TEXT NOT NULL,
  customer_phone_snapshot VARCHAR(20) NOT NULL,
  customer_name_snapshot VARCHAR(100) NOT NULL,
  special_instructions TEXT,
  is_scheduled BOOLEAN NOT NULL DEFAULT FALSE,
  scheduled_for TIMESTAMPTZ NULL,
  subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
  delivery_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0),
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0),
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
  total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
  fulfillment_status VARCHAR(30) NOT NULL DEFAULT 'PLACED' CHECK (fulfillment_status IN ('PLACED', 'CONFIRMED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')),
  payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'REFUNDED', 'FAILED')),
  payment_method VARCHAR(30) NOT NULL DEFAULT 'CASH_ON_DELIVERY',
  idempotency_key VARCHAR(100) UNIQUE NULL,
  cancellation_reason TEXT NULL,
  cancelled_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Order Items table (Immutable line item snapshots at purchase time)
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id UUID NULL REFERENCES menu_items(id) ON DELETE SET NULL,
  item_name_snapshot VARCHAR(255) NOT NULL,
  item_description_snapshot TEXT NULL,
  unit_price_snapshot NUMERIC(12, 2) NOT NULL CHECK (unit_price_snapshot >= 0),
  is_veg_snapshot BOOLEAN NOT NULL DEFAULT TRUE,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  line_total NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0),
  item_instructions TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Order Status Events table (Audit timeline of all state transitions)
CREATE TABLE IF NOT EXISTS order_status_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status VARCHAR(30) NULL,
  to_status VARCHAR(30) NOT NULL,
  actor_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  actor_role VARCHAR(50) NULL,
  note TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Indexes for query performance and relational lookups
CREATE INDEX IF NOT EXISTS idx_carts_customer ON carts (customer_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items (cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_menu_item ON cart_items (menu_item_id);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant ON orders (restaurant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_fulfillment_status ON orders (fulfillment_status);
CREATE INDEX IF NOT EXISTS idx_orders_idempotency ON orders (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_orders_public_number ON orders (public_order_number);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_events_order ON order_status_events (order_id, created_at ASC);


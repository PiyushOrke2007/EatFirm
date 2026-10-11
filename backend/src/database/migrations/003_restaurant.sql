-- Migration 003_restaurant: Restaurant Onboarding, Operating Hours, Categories, and Menu Items
-- SRS: REST-1, REST-2, REST-3, REST-4, REST-5, REST-6, Section 6 (Food License), NFR-12 (Veg/Non-Veg)

-- 1. Create restaurants table
CREATE TABLE IF NOT EXISTS restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  address TEXT NOT NULL,
  phone VARCHAR(20) NOT NULL,
  cuisine_type VARCHAR(100) NOT NULL,
  food_license_number VARCHAR(100) NOT NULL,
  image_url TEXT,
  approval_status VARCHAR(30) NOT NULL DEFAULT 'PENDING_APPROVAL' CHECK (approval_status IN ('PENDING_APPROVAL', 'APPROVED', 'REJECTED')),
  rejection_reason TEXT,
  is_open BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_restaurants_owner_id UNIQUE (owner_id)
);

CREATE INDEX IF NOT EXISTS idx_restaurants_owner_id ON restaurants (owner_id);
CREATE INDEX IF NOT EXISTS idx_restaurants_approval_status ON restaurants (approval_status);
CREATE INDEX IF NOT EXISTS idx_restaurants_cuisine ON restaurants (cuisine_type);

-- 2. Create operating_hours table (REST-1, REST-5)
CREATE TABLE IF NOT EXISTS operating_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  day_of_week VARCHAR(10) NOT NULL CHECK (day_of_week IN ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY')),
  open_time VARCHAR(5) NOT NULL, -- HH:MM
  close_time VARCHAR(5) NOT NULL, -- HH:MM
  is_closed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_restaurant_day UNIQUE (restaurant_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_operating_hours_restaurant ON operating_hours (restaurant_id);

-- 3. Create menu_categories table (REST-3)
CREATE TABLE IF NOT EXISTS menu_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_category_restaurant_name UNIQUE (restaurant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_menu_categories_restaurant ON menu_categories (restaurant_id, sort_order);

-- 4. Create menu_items table (REST-3, REST-4, REST-5, REST-6, NFR-12)
CREATE TABLE IF NOT EXISTS menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE RESTRICT,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  is_veg BOOLEAN NOT NULL DEFAULT TRUE,
  image_url TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  available_from VARCHAR(5), -- HH:MM (REST-5)
  available_until VARCHAR(5), -- HH:MM (REST-5)
  is_special_offer BOOLEAN NOT NULL DEFAULT FALSE, -- REST-6
  offer_price NUMERIC(12,2) CHECK (offer_price IS NULL OR (offer_price >= 0 AND offer_price < price)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant ON menu_items (restaurant_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items (category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items (restaurant_id, is_available);
CREATE INDEX IF NOT EXISTS idx_menu_items_special_offer ON menu_items (restaurant_id, is_special_offer);


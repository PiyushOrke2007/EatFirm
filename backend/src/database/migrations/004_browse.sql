-- Module 04: Customer Restaurant Discovery, Search, Comparison, and Menu Details
-- Migration 004_browse.sql
-- Enforces SRS BROWSE-1, BROWSE-2, BROWSE-3, BROWSE-4, DEC-02, NFR-4

-- 1. Add geolocation coordinates, ratings, and delivery metrics to restaurants table
ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7) DEFAULT 12.9716000,
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7) DEFAULT 77.5946000,
  ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3, 2) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS rating_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS estimated_delivery_mins INTEGER NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS price_tier VARCHAR(10) NOT NULL DEFAULT '₹₹';

-- 2. Constraints
ALTER TABLE restaurants
  ADD CONSTRAINT chk_restaurants_lat_range CHECK (latitude >= -90 AND latitude <= 90),
  ADD CONSTRAINT chk_restaurants_lng_range CHECK (longitude >= -180 AND longitude <= 180),
  ADD CONSTRAINT chk_restaurants_rating_range CHECK (average_rating IS NULL OR (average_rating >= 1.0 AND average_rating <= 5.0)),
  ADD CONSTRAINT chk_restaurants_rating_count CHECK (rating_count >= 0),
  ADD CONSTRAINT chk_restaurants_delivery_time CHECK (estimated_delivery_mins > 0);

-- 3. Update existing seed/test restaurants with diverse mock locations around Bengaluru
UPDATE restaurants
SET latitude = 12.9784, longitude = 77.6408, average_rating = 4.5, rating_count = 128, estimated_delivery_mins = 25, price_tier = '₹₹'
WHERE latitude = 12.9716000 AND id IN (SELECT id FROM restaurants LIMIT 1);

-- 4. Search and filter performance indexes (NFR-4)
CREATE INDEX IF NOT EXISTS idx_restaurants_browse_status ON restaurants (approval_status, is_open);
CREATE INDEX IF NOT EXISTS idx_restaurants_cuisine_browse ON restaurants (cuisine_type);
CREATE INDEX IF NOT EXISTS idx_restaurants_rating ON restaurants (average_rating DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_restaurants_coords ON restaurants (latitude, longitude);

-- Text search indexes for restaurant name and cuisine
CREATE INDEX IF NOT EXISTS idx_restaurants_name_search ON restaurants (LOWER(name));
CREATE INDEX IF NOT EXISTS idx_menu_items_name_search ON menu_items (LOWER(name));
CREATE INDEX IF NOT EXISTS idx_menu_items_veg_filter ON menu_items (restaurant_id, is_veg, is_available);


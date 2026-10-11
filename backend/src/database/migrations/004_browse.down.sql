-- Module 04: Rollback migration
-- 004_browse.down.sql

DROP INDEX IF EXISTS idx_menu_items_veg_filter;
DROP INDEX IF EXISTS idx_menu_items_name_search;
DROP INDEX IF EXISTS idx_restaurants_name_search;
DROP INDEX IF EXISTS idx_restaurants_coords;
DROP INDEX IF EXISTS idx_restaurants_rating;
DROP INDEX IF EXISTS idx_restaurants_cuisine_browse;
DROP INDEX IF EXISTS idx_restaurants_browse_status;

ALTER TABLE restaurants
  DROP CONSTRAINT IF EXISTS chk_restaurants_delivery_time,
  DROP CONSTRAINT IF EXISTS chk_restaurants_rating_count,
  DROP CONSTRAINT IF EXISTS chk_restaurants_rating_range,
  DROP CONSTRAINT IF EXISTS chk_restaurants_lng_range,
  DROP CONSTRAINT IF EXISTS chk_restaurants_lat_range;

ALTER TABLE restaurants
  DROP COLUMN IF EXISTS price_tier,
  DROP COLUMN IF EXISTS estimated_delivery_mins,
  DROP COLUMN IF EXISTS rating_count,
  DROP COLUMN IF EXISTS average_rating,
  DROP COLUMN IF EXISTS longitude,
  DROP COLUMN IF EXISTS latitude;


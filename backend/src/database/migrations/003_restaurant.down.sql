-- Migration 003_restaurant Rollback: Drop tables in reverse order of foreign keys
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS menu_categories CASCADE;
DROP TABLE IF EXISTS operating_hours CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;


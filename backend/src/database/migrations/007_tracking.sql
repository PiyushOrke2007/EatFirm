-- Module 07: Order Progress, Status Timeline, and Tracking Updates Migration
-- Migration 007_tracking.sql
-- Enforces SRS TRACK-1, TRACK-2, TRACK-3, TRACK-4, NFR-6, DEC-02

-- 1. Create order_tracking_locations table for real partner location telemetry
CREATE TABLE IF NOT EXISTS order_tracking_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  delivery_partner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  latitude NUMERIC(10, 7) NOT NULL CHECK (latitude >= -90.0 AND latitude <= 90.0),
  longitude NUMERIC(10, 7) NOT NULL CHECK (longitude >= -180.0 AND longitude <= 180.0),
  heading_degrees NUMERIC(5, 2) NULL CHECK (heading_degrees IS NULL OR (heading_degrees >= 0.0 AND heading_degrees <= 360.0)),
  speed_meters_per_sec NUMERIC(6, 2) NULL CHECK (speed_meters_per_sec IS NULL OR speed_meters_per_sec >= 0.0),
  accuracy_meters NUMERIC(6, 2) NULL CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0.0),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Performance indexes for tracking queries (fetch latest location fast per order)
CREATE INDEX IF NOT EXISTS idx_order_tracking_locations_order_recorded 
  ON order_tracking_locations (order_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_tracking_locations_partner 
  ON order_tracking_locations (delivery_partner_id, recorded_at DESC);


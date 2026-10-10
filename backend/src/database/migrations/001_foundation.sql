-- Migration 001_foundation: Extensions, Audit Log, and System Settings

-- 1. UUID extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Audit Logs Table (SRS NFR-27, Foundation Observability)
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action VARCHAR(100) NOT NULL,
  actor_id UUID,
  actor_role VARCHAR(50),
  ip_address VARCHAR(45),
  user_agent TEXT,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id, actor_role);

-- 3. System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
  key VARCHAR(100) PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial system baseline settings
INSERT INTO system_settings (key, value, description)
VALUES 
  ('platform_info', '{"name": "EatFirm", "version": "1.0.0", "currency": "INR", "timezone": "Asia/Kolkata"}'::jsonb, 'Platform metadata and regional configuration')
ON CONFLICT (key) DO NOTHING;


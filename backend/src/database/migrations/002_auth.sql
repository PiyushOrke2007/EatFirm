-- Migration 002_auth: Users, User Sessions, and OTP Verification

-- 1. Create users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255),
  phone VARCHAR(20),
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(30) NOT NULL CHECK (role IN ('CUSTOMER', 'RESTAURANT_ADMIN', 'DELIVERY_PARTNER', 'SYSTEM_ADMIN')),
  account_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (account_status IN ('ACTIVE', 'PENDING_VERIFICATION', 'SUSPENDED', 'DEACTIVATED')),
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  terms_accepted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_unique_email ON users (LOWER(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_unique_phone ON users (phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_account_status ON users (account_status);

-- 2. Create user_sessions table (Session lifecycle, JWT revocation, SRS NFR-21)
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  ip_address VARCHAR(45),
  user_agent TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_lookup ON user_sessions (user_id, revoked_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expiry ON user_sessions (expires_at);

-- 3. Create otps table (OTP verification & password reset, SRS REG-3, LOGIN-2, NFR-25)
CREATE TABLE IF NOT EXISTS otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target VARCHAR(255) NOT NULL,
  otp_code VARCHAR(10) NOT NULL,
  purpose VARCHAR(30) NOT NULL CHECK (purpose IN ('REGISTRATION', 'PASSWORD_RESET')),
  expires_at TIMESTAMPTZ NOT NULL,
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_otps_target_purpose ON otps (target, purpose, is_used);
CREATE INDEX IF NOT EXISTS idx_otps_expiry ON otps (expires_at);

-- 4. Seed initial System Administrator account (Password: Admin@EatFirm2026!)
-- Hash generated with bcryptjs rounds=10: $2a$10$w4rU8q0rJ6G5LqXUqgT0QO5zXlZ.7M4XJ5z6w8q0rJ6G5LqXUqgT0
INSERT INTO users (
  name,
  email,
  phone,
  password_hash,
  role,
  account_status,
  is_verified,
  terms_accepted_at
)
VALUES (
  'System Administrator',
  'admin@eatfirm.com',
  '9999999999',
  '$2b$10$dl79.OjQMSFFJpgBsaYheejaf6y5S9ZV1DCOBaCt3Xh1pQRodGL8K',
  'SYSTEM_ADMIN',
  'ACTIVE',
  TRUE,
  CURRENT_TIMESTAMP
)
ON CONFLICT DO NOTHING;

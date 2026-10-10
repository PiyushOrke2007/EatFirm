-- Rollback Migration 002_auth: Users, User Sessions, and OTP Verification

DROP TABLE IF EXISTS otps CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- Rollback Module 06: Drop invoices, payment_events, and payments tables

DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS payment_events CASCADE;
DROP TABLE IF EXISTS payments CASCADE;


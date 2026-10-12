-- Module 06: COD Payment Records, Payment Status, and Invoicing Migration
-- Authoritative tables for payments, audit events, and immutable tax invoices (SRS PAY-1..4)

-- 1. Payments Table (Authoritative payment record associated with each order, PAY-01, PAY-02)
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT,
  payment_method VARCHAR(30) NOT NULL DEFAULT 'CASH_ON_DELIVERY',
  payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency VARCHAR(10) NOT NULL DEFAULT 'INR',
  collected_at TIMESTAMPTZ NULL,
  collected_by_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  transaction_reference VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Payment Events Table (Audit log for payment state transitions, PAY-03, PAY-05, NFR-16)
CREATE TABLE IF NOT EXISTS payment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  from_status VARCHAR(30) NULL,
  to_status VARCHAR(30) NOT NULL,
  actor_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  actor_role VARCHAR(50) NULL,
  transaction_reference VARCHAR(100) NULL,
  note TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Invoices Table (Immutable tax invoice generated from order snapshot, PAY-04)
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT,
  invoice_number VARCHAR(40) NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE RESTRICT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
  delivery_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0),
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0),
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
  total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
  currency VARCHAR(10) NOT NULL DEFAULT 'INR',
  payment_method VARCHAR(30) NOT NULL DEFAULT 'CASH_ON_DELIVERY',
  payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  recipient_name VARCHAR(100) NOT NULL,
  recipient_phone VARCHAR(20) NOT NULL,
  delivery_address TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Performance & Relational Indexes
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (payment_status);
CREATE INDEX IF NOT EXISTS idx_payment_events_payment ON payment_events (payment_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_invoices_order ON invoices (order_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_restaurant ON invoices (restaurant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices (invoice_number);

-- 5. Backfill payments for any existing orders that don't have a payment record yet (PAY-01)
INSERT INTO payments (order_id, payment_method, payment_status, amount, currency, created_at, updated_at)
SELECT o.id, o.payment_method, o.payment_status, o.total_amount, 'INR', o.created_at, o.updated_at
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
WHERE p.id IS NULL
ON CONFLICT (order_id) DO NOTHING;


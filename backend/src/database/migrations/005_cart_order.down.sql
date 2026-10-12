-- Rollback for Module 05: Cart, Checkout, Order Placement, Order History, and Cancellation
-- Migration 005_cart_order.down.sql

DROP TABLE IF EXISTS order_status_events CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;


import test from 'node:test';
import assert from 'node:assert/strict';
import {
  toPaise,
  fromPaise,
  addMoney,
  subtractMoney,
  multiplyMoney,
  formatINR,
} from '../src/utils/money.js';

test('toPaise converts rupees string and float correctly', () => {
  assert.strictEqual(toPaise('10.50'), 1050);
  assert.strictEqual(toPaise('0.99'), 99);
  assert.strictEqual(toPaise('100'), 10000);
  assert.strictEqual(toPaise(25.75), 2575);
});

test('fromPaise converts paise to decimal string', () => {
  assert.strictEqual(fromPaise(1050), '10.50');
  assert.strictEqual(fromPaise(99), '0.99');
  assert.strictEqual(fromPaise(10000), '100.00');
  assert.strictEqual(fromPaise(5), '0.05');
});

test('addMoney adds exact amounts without IEEE 754 precision errors', () => {
  // In IEEE 754 float: 0.1 + 0.2 = 0.30000000000000004
  assert.strictEqual(addMoney('0.10', '0.20'), '0.30');
  assert.strictEqual(addMoney('149.99', '50.01'), '200.00');
});

test('subtractMoney subtracts amounts precisely', () => {
  assert.strictEqual(subtractMoney('100.00', '25.50'), '74.50');
});

test('multiplyMoney applies commercial rounding accurately', () => {
  assert.strictEqual(multiplyMoney('100.00', 0.05), '5.00'); // 5% tax
  assert.strictEqual(multiplyMoney('49.99', 2), '99.98');
});

test('formatINR formats with Indian digit grouping and Rupee symbol', () => {
  assert.strictEqual(formatINR('500.00'), '₹500.00');
  assert.strictEqual(formatINR('1250.50'), '₹1,250.50');
  assert.strictEqual(formatINR('1234567.89'), '₹12,34,567.89');
  assert.strictEqual(formatINR('10000000.00'), '₹1,00,00,000.00'); // 1 crore
});


/**
 * Money utilities adhering to SRS CO-7 and Section 6:
 * - Exact decimal calculations without floating-point rounding errors.
 * - Indian digit grouping and currency formatting (INR).
 */

/**
 * Converts a decimal monetary value (e.g. 12.50 or "12.50") into integer paise (1250).
 */
export function toPaise(amount: string | number): number {
  if (typeof amount === 'number') {
    // Avoid float multiplication artifacts by formatting to 2 decimal places first
    amount = amount.toFixed(2);
  }

  const trimmed = amount.trim();
  const match = trimmed.match(/^(-?\d+)(?:\.(\d{1,2}))?$/);
  if (!match) {
    throw new Error(`Invalid monetary amount format: "${amount}"`);
  }

  const sign = trimmed.startsWith('-') ? -1 : 1;
  const wholePart = Math.abs(parseInt(match[1], 10));
  const fractionPart = match[2] ? match[2].padEnd(2, '0').slice(0, 2) : '00';

  return sign * (wholePart * 100 + parseInt(fractionPart, 10));
}

/**
 * Converts integer paise into an exact decimal string with 2 decimal places (e.g. 1250 -> "12.50").
 */
export function fromPaise(paise: number): string {
  if (!Number.isInteger(paise)) {
    throw new Error(`Paise amount must be an integer, received: ${paise}`);
  }

  const isNegative = paise < 0;
  const absPaise = Math.abs(paise);
  const rupees = Math.floor(absPaise / 100);
  const fraction = (absPaise % 100).toString().padStart(2, '0');

  return `${isNegative ? '-' : ''}${rupees}.${fraction}`;
}

/**
 * Adds two monetary amounts with exact precision.
 */
export function addMoney(a: string | number, b: string | number): string {
  return fromPaise(toPaise(a) + toPaise(b));
}

/**
 * Subtracts b from a with exact precision.
 */
export function subtractMoney(a: string | number, b: string | number): string {
  return fromPaise(toPaise(a) - toPaise(b));
}

/**
 * Multiplies a monetary amount by a scalar quantity or percentage.
 * Rounds to the nearest paise using standard commercial rounding (round half away from zero).
 */
export function multiplyMoney(amount: string | number, multiplier: number): string {
  const paise = toPaise(amount);
  const resultPaise = Math.round(paise * multiplier);
  return fromPaise(resultPaise);
}

/**
 * Formats a monetary amount into standard Indian Rupee notation (e.g. ₹1,23,456.75).
 * Uses Indian digit grouping: 3 digits at the right, then groups of 2 digits.
 */
export function formatINR(amount: string | number): string {
  const decimalStr = typeof amount === 'number' ? fromPaise(toPaise(amount)) : fromPaise(toPaise(amount));
  const [rupees, paise] = decimalStr.split('.');

  const isNegative = rupees.startsWith('-');
  const cleanRupees = isNegative ? rupees.slice(1) : rupees;

  let formattedRupees = '';
  if (cleanRupees.length <= 3) {
    formattedRupees = cleanRupees;
  } else {
    const lastThree = cleanRupees.slice(-3);
    const rest = cleanRupees.slice(0, -3);
    const parts: string[] = [];
    for (let i = rest.length; i > 0; i -= 2) {
      const start = Math.max(0, i - 2);
      parts.unshift(rest.slice(start, i));
    }
    formattedRupees = parts.join(',') + ',' + lastThree;
  }

  return `${isNegative ? '-' : ''}₹${formattedRupees}.${paise}`;
}


import crypto from 'crypto';
import { pool } from '../database/db.js';
import { logger } from '../logger/index.js';

export type OtpPurpose = 'REGISTRATION' | 'PASSWORD_RESET';

export interface GeneratedOtp {
  target: string;
  code: string;
  purpose: OtpPurpose;
  expiresAt: Date;
}

/**
 * Notification Service (SMS & Email OTP Adapter):
 * release 1.0 utilizes console & structured logger adapter for dev/evaluation.
 * Production external providers (e.g. Twilio, MSG91, AWS SES) connect via this interface.
 */
export async function generateAndSendOtp(
  target: string,
  purpose: OtpPurpose,
  expiryMinutes = 10
): Promise<GeneratedOtp> {
  const code = crypto.randomInt(100000, 999999).toString();
  const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);

  // Invalidate previous unused OTPs for this target & purpose
  await pool.query(
    `UPDATE otps SET is_used = TRUE WHERE target = $1 AND purpose = $2 AND is_used = FALSE`,
    [target, purpose]
  );

  // Insert newly generated OTP
  await pool.query(
    `INSERT INTO otps (target, otp_code, purpose, expires_at, is_used, created_at)
     VALUES ($1, $2, $3, $4, FALSE, CURRENT_TIMESTAMP)`,
    [target, code, purpose, expiresAt]
  );

  logger.info(`[NOTIFICATION-ADAPTER] Generated ${purpose} OTP for ${target}`, {
    target,
    purpose,
    otpCode: code, // Visible in dev logger for verification and automated tests
    expiresAt: expiresAt.toISOString(),
  });

  return { target, code, purpose, expiresAt };
}

/**
 * Verifies an OTP code against the database.
 */
export async function verifyOtpCode(
  target: string,
  code: string,
  purpose: OtpPurpose
): Promise<boolean> {
  const result = await pool.query<{ id: string }>(
    `SELECT id FROM otps
     WHERE target = $1 AND otp_code = $2 AND purpose = $3 AND is_used = FALSE AND expires_at > CURRENT_TIMESTAMP
     ORDER BY created_at DESC
     LIMIT 1`,
    [target, code.trim(), purpose]
  );

  if (result.rows.length === 0) {
    return false;
  }

  // Mark OTP as used to prevent replay attacks
  await pool.query(`UPDATE otps SET is_used = TRUE WHERE id = $1`, [result.rows[0].id]);
  return true;
}


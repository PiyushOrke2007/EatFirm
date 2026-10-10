import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../database/db.js';
import { config } from '../config/index.js';
import {
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  NotFoundError,
} from '../middleware/errorHandler.js';
import { UserRole } from '../middleware/authGuard.js';
import { logAuditEvent } from './auditService.js';
import { generateAndSendOtp, verifyOtpCode, OtpPurpose } from './notificationService.js';

export interface SanitizedUser {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  role: UserRole;
  accountStatus: string;
  isVerified: boolean;
  termsAcceptedAt: string;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface RegisterInput {
  name: string;
  email?: string;
  phone?: string;
  password: string;
  role: 'CUSTOMER' | 'RESTAURANT_ADMIN' | 'DELIVERY_PARTNER';
  termsAccepted: boolean;
}

export interface LoginInput {
  identifier: string;
  password: string;
  ipAddress?: string;
  userAgent?: string;
}

export interface AuthSessionResult {
  token: string;
  user: SanitizedUser;
  expiresAt: string;
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function sanitizeUser(row: any): SanitizedUser {
  return {
    id: row.id,
    name: row.name,
    email: row.email || null,
    phone: row.phone || null,
    role: row.role,
    accountStatus: row.account_status,
    isVerified: Boolean(row.is_verified),
    termsAcceptedAt: row.terms_accepted_at ? new Date(row.terms_accepted_at).toISOString() : '',
    lastLoginAt: row.last_login_at ? new Date(row.last_login_at).toISOString() : null,
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

export class AuthService {
  /**
   * AUTH-01: User Registration
   * Enforces valid roles, strong passwords, normalized credentials, terms acceptance.
   * Disallows public assignment of SYSTEM_ADMIN (SRS REG-1).
   */
  static async register(input: RegisterInput): Promise<{ user: SanitizedUser; otpSentTo: string }> {
    const trimmedName = input.name?.trim();
    if (!trimmedName || trimmedName.length < 2 || trimmedName.length > 100) {
      throw new ValidationError('Name must be between 2 and 100 characters', [
        { field: 'name', message: 'Name must be between 2 and 100 characters' },
      ]);
    }

    if (!input.termsAccepted) {
      throw new ValidationError('You must accept the Terms of Service to create an account', [
        { field: 'termsAccepted', message: 'Terms of Service acceptance is required' },
      ]);
    }

    const allowedPublicRoles: UserRole[] = ['CUSTOMER', 'RESTAURANT_ADMIN', 'DELIVERY_PARTNER'];
    if (!allowedPublicRoles.includes(input.role)) {
      throw new ValidationError(
        'System Administrator registration is restricted and cannot be created publicly',
        [{ field: 'role', message: 'Public registration is restricted to CUSTOMER, RESTAURANT_ADMIN, or DELIVERY_PARTNER' }]
      );
    }

    const normalizedEmail = input.email ? input.email.trim().toLowerCase() : undefined;
    const normalizedPhone = input.phone ? input.phone.trim().replace(/\D/g, '') : undefined;

    if (!normalizedEmail && !normalizedPhone) {
      throw new ValidationError('At least one of email or phone number is required', [
        { field: 'email', message: 'Email or phone number must be provided' },
      ]);
    }

    if (normalizedEmail) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(normalizedEmail)) {
        throw new ValidationError('Invalid email address format', [
          { field: 'email', message: 'Please enter a valid email address' },
        ]);
      }
    }

    if (normalizedPhone) {
      if (normalizedPhone.length !== 10) {
        throw new ValidationError('Phone number must be exactly 10 digits', [
          { field: 'phone', message: 'Please enter a valid 10-digit Indian phone number' },
        ]);
      }
    }

    // Password strength check (min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special character)
    const password = input.password || '';
    const hasMinLen = password.length >= 8;
    const hasUpper = /[A-Z]/.test(password);
    const hasLower = /[a-z]/.test(password);
    const hasDigit = /[0-9]/.test(password);
    const hasSpecial = /[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]/.test(password);

    if (!hasMinLen || !hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      throw new ValidationError(
        'Password must be at least 8 characters long and contain uppercase, lowercase, digit, and special character',
        [
          {
            field: 'password',
            message:
              'Password requires at least 8 characters, 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special symbol',
          },
        ]
      );
    }

    // Check unique email and phone
    if (normalizedEmail) {
      const existingEmail = await pool.query(`SELECT id FROM users WHERE LOWER(email) = $1`, [
        normalizedEmail,
      ]);
      if (existingEmail.rows.length > 0) {
        throw new ConflictError('An account with this email address already exists');
      }
    }

    if (normalizedPhone) {
      const existingPhone = await pool.query(`SELECT id FROM users WHERE phone = $1`, [
        normalizedPhone,
      ]);
      if (existingPhone.rows.length > 0) {
        throw new ConflictError('An account with this phone number already exists');
      }
    }

    // Hash password with bcryptjs (rounds=10)
    const passwordHash = await bcrypt.hash(password, 10);

    const insertResult = await pool.query(
      `INSERT INTO users (
        name,
        email,
        phone,
        password_hash,
        role,
        account_status,
        is_verified,
        terms_accepted_at,
        created_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, 'ACTIVE', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING *`,
      [trimmedName, normalizedEmail || null, normalizedPhone || null, passwordHash, input.role]
    );

    const newUser = insertResult.rows[0];
    const otpTarget = normalizedEmail || normalizedPhone!;

    // Generate registration OTP
    await generateAndSendOtp(otpTarget, 'REGISTRATION');

    await logAuditEvent({
      action: 'USER_REGISTERED',
      actorId: newUser.id,
      actorRole: newUser.role,
      details: { email: normalizedEmail, phone: normalizedPhone, role: newUser.role },
    });

    return {
      user: sanitizeUser(newUser),
      otpSentTo: otpTarget,
    };
  }

  /**
   * AUTH-02: User Login
   * Authenticates against email/phone and password, returns safe generic error on bad credentials.
   * Generates JWT session and records in user_sessions (SRS LOGIN-1, LOGIN-3).
   */
  static async login(input: LoginInput): Promise<AuthSessionResult> {
    const rawIdentifier = input.identifier?.trim();
    if (!rawIdentifier || !input.password) {
      throw new ValidationError('Email or phone, and password are required', [
        { field: 'identifier', message: 'Identifier and password must be provided' },
      ]);
    }

    const cleanPhone = rawIdentifier.replace(/\D/g, '');
    const isPhoneCandidate = cleanPhone.length === 10;
    const lowerIdentifier = rawIdentifier.toLowerCase();

    const userResult = await pool.query(
      `SELECT * FROM users
       WHERE LOWER(email) = $1
          OR ($2 = TRUE AND phone = $3)
       LIMIT 1`,
      [lowerIdentifier, isPhoneCandidate, cleanPhone]
    );

    if (userResult.rows.length === 0) {
      await logAuditEvent({
        action: 'LOGIN_FAILED',
        ipAddress: input.ipAddress,
        userAgent: input.userAgent,
        details: { identifier: rawIdentifier, reason: 'USER_NOT_FOUND' },
      });
      throw new UnauthorizedError('Invalid email/phone or password');
    }

    const user = userResult.rows[0];

    // Check account status
    if (user.account_status === 'SUSPENDED') {
      throw new ForbiddenError('Your account has been suspended. Please contact support.');
    }
    if (user.account_status === 'DEACTIVATED') {
      throw new ForbiddenError('Your account has been deactivated. Please contact support.');
    }

    // Verify password hash
    const isValidPassword = await bcrypt.compare(input.password, user.password_hash);
    if (!isValidPassword) {
      await logAuditEvent({
        action: 'LOGIN_FAILED',
        actorId: user.id,
        actorRole: user.role,
        ipAddress: input.ipAddress,
        userAgent: input.userAgent,
        details: { reason: 'PASSWORD_MISMATCH' },
      });
      throw new UnauthorizedError('Invalid email/phone or password');
    }

    // Session lifespan: 7 days
    const sessionDurationMs = 7 * 24 * 60 * 60 * 1000;
    const expiresAt = new Date(Date.now() + sessionDurationMs);

    // Issue JWT token with unique token identifier (jti)
    const token = jwt.sign(
      {
        jti: crypto.randomUUID(),
        sub: user.id,
        role: user.role,
        email: user.email,
        phone: user.phone,
        name: user.name,
      },
      config.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const tokenHash = hashToken(token);

    // Persist session to user_sessions table
    await pool.query(
      `INSERT INTO user_sessions (user_id, token_hash, ip_address, user_agent, expires_at, created_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)`,
      [user.id, tokenHash, input.ipAddress || null, input.userAgent || null, expiresAt]
    );

    // Update user last_login_at
    await pool.query(
      `UPDATE users SET last_login_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [user.id]
    );

    await logAuditEvent({
      action: 'LOGIN_SUCCESS',
      actorId: user.id,
      actorRole: user.role,
      ipAddress: input.ipAddress,
      userAgent: input.userAgent,
    });

    return {
      token,
      user: sanitizeUser(user),
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * AUTH-03: Verify OTP
   * Verifies registration or password reset OTP.
   */
  static async verifyOtp(
    target: string,
    otpCode: string,
    purpose: OtpPurpose
  ): Promise<{ success: boolean; message: string }> {
    const cleanTarget = target.trim().toLowerCase();
    const cleanPhone = target.trim().replace(/\D/g, '');
    const effectiveTarget = cleanPhone.length === 10 ? cleanPhone : cleanTarget;

    const isValid = await verifyOtpCode(effectiveTarget, otpCode, purpose);
    if (!isValid) {
      throw new ValidationError('Invalid or expired verification code', [
        { field: 'otpCode', message: 'The verification code entered is invalid or has expired' },
      ]);
    }

    if (purpose === 'REGISTRATION') {
      await pool.query(
        `UPDATE users
         SET is_verified = TRUE, updated_at = CURRENT_TIMESTAMP
         WHERE LOWER(email) = $1 OR phone = $2`,
        [cleanTarget, cleanPhone]
      );

      await logAuditEvent({
        action: 'OTP_VERIFIED',
        details: { target: effectiveTarget, purpose },
      });
    }

    return {
      success: true,
      message:
        purpose === 'REGISTRATION'
          ? 'Account successfully verified'
          : 'Verification code confirmed for password reset',
    };
  }

  /**
   * Resend OTP for registration or password reset
   */
  static async resendOtp(
    target: string,
    purpose: OtpPurpose
  ): Promise<{ success: boolean; message: string }> {
    const cleanTarget = target.trim().toLowerCase();
    const cleanPhone = target.trim().replace(/\D/g, '');
    const effectiveTarget = cleanPhone.length === 10 ? cleanPhone : cleanTarget;

    await generateAndSendOtp(effectiveTarget, purpose);

    return {
      success: true,
      message: `A new verification code has been sent to ${effectiveTarget}`,
    };
  }

  /**
   * AUTH-04: Logout & Session Revocation
   * Revokes the active session in user_sessions table (SRS NFR-21).
   */
  static async logout(token: string, userId?: string): Promise<{ success: boolean }> {
    const tokenHash = hashToken(token);

    await pool.query(
      `UPDATE user_sessions
       SET revoked_at = CURRENT_TIMESTAMP
       WHERE token_hash = $1`,
      [tokenHash]
    );

    if (userId) {
      await logAuditEvent({
        action: 'LOGOUT',
        actorId: userId,
      });
    }

    return { success: true };
  }

  /**
   * Password Reset Flow (SRS LOGIN-2)
   */
  static async forgotPassword(identifier: string): Promise<{ message: string }> {
    const raw = identifier.trim();
    const cleanPhone = raw.replace(/\D/g, '');
    const isPhone = cleanPhone.length === 10;
    const lower = raw.toLowerCase();

    const userResult = await pool.query(
      `SELECT * FROM users
       WHERE LOWER(email) = $1 OR ($2 = TRUE AND phone = $3)
       LIMIT 1`,
      [lower, isPhone, cleanPhone]
    );

    // Generic safe response to prevent user enumeration
    if (userResult.rows.length === 0) {
      return { message: 'If an account exists with that identifier, a verification code has been sent.' };
    }

    const user = userResult.rows[0];
    const target = user.email || user.phone;

    await generateAndSendOtp(target, 'PASSWORD_RESET');

    await logAuditEvent({
      action: 'PASSWORD_RESET_REQUESTED',
      actorId: user.id,
      actorRole: user.role,
    });

    return { message: 'If an account exists with that identifier, a verification code has been sent.' };
  }

  /**
   * Reset Password using OTP
   */
  static async resetPassword(
    identifier: string,
    otpCode: string,
    newPassword: string
  ): Promise<{ success: boolean; message: string }> {
    const raw = identifier.trim();
    const cleanPhone = raw.replace(/\D/g, '');
    const isPhone = cleanPhone.length === 10;
    const lower = raw.toLowerCase();

    const userResult = await pool.query(
      `SELECT * FROM users
       WHERE LOWER(email) = $1 OR ($2 = TRUE AND phone = $3)
       LIMIT 1`,
      [lower, isPhone, cleanPhone]
    );

    if (userResult.rows.length === 0) {
      throw new ValidationError('Invalid request or expired code');
    }

    const user = userResult.rows[0];
    const target = user.email || user.phone;

    const isValid = await verifyOtpCode(target, otpCode, 'PASSWORD_RESET');
    if (!isValid) {
      throw new ValidationError('Invalid or expired verification code', [
        { field: 'otpCode', message: 'Verification code is invalid or has expired' },
      ]);
    }

    // Password strength check
    const hasMinLen = newPassword.length >= 8;
    const hasUpper = /[A-Z]/.test(newPassword);
    const hasLower = /[a-z]/.test(newPassword);
    const hasDigit = /[0-9]/.test(newPassword);
    const hasSpecial = /[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]/.test(newPassword);

    if (!hasMinLen || !hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      throw new ValidationError(
        'Password must be at least 8 characters long and contain uppercase, lowercase, digit, and special character',
        [
          {
            field: 'newPassword',
            message:
              'Password requires at least 8 characters, 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special symbol',
          },
        ]
      );
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    // Update password in users table
    await pool.query(
      `UPDATE users
       SET password_hash = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [passwordHash, user.id]
    );

    // Invalidate all existing sessions for this user for security
    await pool.query(
      `UPDATE user_sessions
       SET revoked_at = CURRENT_TIMESTAMP
       WHERE user_id = $1 AND revoked_at IS NULL`,
      [user.id]
    );

    await logAuditEvent({
      action: 'PASSWORD_RESET_SUCCESS',
      actorId: user.id,
      actorRole: user.role,
    });

    return {
      success: true,
      message: 'Password has been reset successfully. Please log in with your new password.',
    };
  }

  /**
   * AUTH-06: Profile retrieval & updates
   */
  static async getProfile(userId: string): Promise<SanitizedUser> {
    const result = await pool.query(`SELECT * FROM users WHERE id = $1`, [userId]);
    if (result.rows.length === 0) {
      throw new NotFoundError('User profile not found');
    }
    return sanitizeUser(result.rows[0]);
  }

  static async updateProfile(
    userId: string,
    updates: { name?: string; phone?: string }
  ): Promise<SanitizedUser> {
    const userResult = await pool.query(`SELECT * FROM users WHERE id = $1`, [userId]);
    if (userResult.rows.length === 0) {
      throw new NotFoundError('User profile not found');
    }

    let name = userResult.rows[0].name;
    let phone = userResult.rows[0].phone;

    if (updates.name !== undefined) {
      const trimmed = updates.name.trim();
      if (trimmed.length < 2 || trimmed.length > 100) {
        throw new ValidationError('Name must be between 2 and 100 characters');
      }
      name = trimmed;
    }

    if (updates.phone !== undefined) {
      const cleanPhone = updates.phone.trim().replace(/\D/g, '');
      if (cleanPhone.length !== 10) {
        throw new ValidationError('Phone number must be exactly 10 digits');
      }
      // Check phone uniqueness if changed
      if (cleanPhone !== phone) {
        const check = await pool.query(`SELECT id FROM users WHERE phone = $1 AND id != $2`, [
          cleanPhone,
          userId,
        ]);
        if (check.rows.length > 0) {
          throw new ConflictError('This phone number is already registered to another account');
        }
      }
      phone = cleanPhone;
    }

    const updatedResult = await pool.query(
      `UPDATE users
       SET name = $1, phone = $2, updated_at = CURRENT_TIMESTAMP
       WHERE id = $3
       RETURNING *`,
      [name, phone, userId]
    );

    return sanitizeUser(updatedResult.rows[0]);
  }
}

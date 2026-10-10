import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AuthService } from '../services/authService.js';
import { sendSuccess } from '../utils/response.js';
import { requireAuth, requireRoles } from '../middleware/authGuard.js';

export const authRouter = Router();

const registerSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email().optional(),
  phone: z.string().optional(),
  password: z.string().min(8),
  role: z.enum(['CUSTOMER', 'RESTAURANT_ADMIN', 'DELIVERY_PARTNER', 'SYSTEM_ADMIN']),
  termsAccepted: z.boolean(),
});

const loginSchema = z.object({
  identifier: z.string().min(1),
  password: z.string().min(1),
});

const verifyOtpSchema = z.object({
  target: z.string().min(1),
  otpCode: z.string().length(6),
  purpose: z.enum(['REGISTRATION', 'PASSWORD_RESET']).default('REGISTRATION'),
});

const resendOtpSchema = z.object({
  target: z.string().min(1),
  purpose: z.enum(['REGISTRATION', 'PASSWORD_RESET']).default('REGISTRATION'),
});

const forgotPasswordSchema = z.object({
  identifier: z.string().min(1),
});

const resetPasswordSchema = z.object({
  identifier: z.string().min(1),
  otpCode: z.string().length(6),
  newPassword: z.string().min(8),
});

const updateProfileSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  phone: z.string().length(10).optional(),
});

/**
 * POST /api/v1/auth/register
 * Register a new user (Customer, Restaurant Admin, Delivery Partner).
 */
authRouter.post('/auth/register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = registerSchema.parse(req.body);
    const result = await AuthService.register(validated as any);
    sendSuccess(
      res,
      {
        user: result.user,
        otpSentTo: result.otpSentTo,
        message: 'Registration successful. A verification OTP has been generated.',
      },
      201
    );
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/login
 * User login with email/phone and password.
 */
authRouter.post('/auth/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = loginSchema.parse(req.body);
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];

    const result = await AuthService.login({
      identifier: validated.identifier,
      password: validated.password,
      ipAddress,
      userAgent,
    });

    sendSuccess(res, result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/verify-otp
 * Verifies 6-digit registration or password reset OTP.
 */
authRouter.post('/auth/verify-otp', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = verifyOtpSchema.parse(req.body);
    const result = await AuthService.verifyOtp(validated.target, validated.otpCode, validated.purpose);
    sendSuccess(res, result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/resend-otp
 * Resend OTP code.
 */
authRouter.post('/auth/resend-otp', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = resendOtpSchema.parse(req.body);
    const result = await AuthService.resendOtp(validated.target, validated.purpose);
    sendSuccess(res, result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/forgot-password
 * Initiates password reset via OTP.
 */
authRouter.post('/auth/forgot-password', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = forgotPasswordSchema.parse(req.body);
    const result = await AuthService.forgotPassword(validated.identifier);
    sendSuccess(res, result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/reset-password
 * Completes password reset using verified OTP.
 */
authRouter.post('/auth/reset-password', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = resetPasswordSchema.parse(req.body);
    const result = await AuthService.resetPassword(
      validated.identifier,
      validated.otpCode,
      validated.newPassword
    );
    sendSuccess(res, result);
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/auth/logout
 * Revokes active session.
 */
authRouter.post('/auth/logout', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (req.token) {
      await AuthService.logout(req.token, req.user?.id);
    }
    sendSuccess(res, { message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/auth/me
 * Retrieves current user profile.
 */
authRouter.get('/auth/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const profile = await AuthService.getProfile(req.user!.id);
    sendSuccess(res, { user: profile });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/v1/auth/profile
 * Updates editable profile attributes.
 */
authRouter.patch('/auth/profile', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const validated = updateProfileSchema.parse(req.body);
    const updated = await AuthService.updateProfile(req.user!.id, validated);
    sendSuccess(res, { user: updated });
  } catch (error) {
    next(error);
  }
});

/**
 * RBAC Verification endpoints for security & contract tests (AUTH-05, AUTH-07)
 */
authRouter.get(
  '/auth/admin-check',
  requireAuth,
  requireRoles('SYSTEM_ADMIN'),
  (_req: Request, res: Response) => {
    sendSuccess(res, { access: 'granted', role: 'SYSTEM_ADMIN' });
  }
);

authRouter.get(
  '/auth/partner-check',
  requireAuth,
  requireRoles('DELIVERY_PARTNER'),
  (_req: Request, res: Response) => {
    sendSuccess(res, { access: 'granted', role: 'DELIVERY_PARTNER' });
  }
);


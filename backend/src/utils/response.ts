import { Request, Response } from 'express';

export interface ApiMeta {
  requestId: string;
  timestamp: string;
  [key: string]: unknown;
}

export interface ApiResponse<T = unknown> {
  success: true;
  data: T;
  meta: ApiMeta;
}

export interface ApiErrorDetail {
  field?: string;
  message: string;
  code?: string;
}

export interface ApiErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: ApiErrorDetail[];
  };
  meta: ApiMeta;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  totalItems: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

export interface PaginatedApiResponse<T = unknown> {
  success: true;
  data: {
    items: T[];
    pagination: PaginationMeta;
  };
  meta: ApiMeta;
}

export function sendSuccess<T>(
  res: Response,
  data: T,
  statusCode = 200,
  extraMeta?: Record<string, unknown>
): Response {
  const requestId = (res.req as { id?: string }).id || 'unknown';
  const responseBody: ApiResponse<T> = {
    success: true,
    data,
    meta: {
      requestId,
      timestamp: new Date().toISOString(),
      ...extraMeta,
    },
  };
  return res.status(statusCode).json(responseBody);
}

export function sendError(
  res: Response,
  statusCode: number,
  code: string,
  message: string,
  details?: ApiErrorDetail[],
  extraMeta?: Record<string, unknown>
): Response {
  const requestId = (res.req as { id?: string }).id || 'unknown';
  const responseBody: ApiErrorResponse = {
    success: false,
    error: {
      code,
      message,
      ...(details && details.length > 0 ? { details } : {}),
    },
    meta: {
      requestId,
      timestamp: new Date().toISOString(),
      ...extraMeta,
    },
  };
  return res.status(statusCode).json(responseBody);
}

export function sendPaginated<T>(
  res: Response,
  items: T[],
  page: number,
  limit: number,
  totalItems: number,
  extraMeta?: Record<string, unknown>
): Response {
  const requestId = (res.req as { id?: string }).id || 'unknown';
  const totalPages = Math.ceil(totalItems / limit) || 1;

  const responseBody: PaginatedApiResponse<T> = {
    success: true,
    data: {
      items,
      pagination: {
        page,
        limit,
        totalItems,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
    },
    meta: {
      requestId,
      timestamp: new Date().toISOString(),
      ...extraMeta,
    },
  };
  return res.status(200).json(responseBody);
}

/**
 * Standard pagination query parameter parser adhering to bounded pagination requirements.
 * Clamps page >= 1, and 1 <= limit <= maxLimit (default max 100).
 */
export function parsePagination(
  req: Request,
  defaultLimit = 20,
  maxLimit = 100
): { page: number; limit: number; offset: number } {
  const rawPage = parseInt(req.query.page as string, 10);
  const rawLimit = parseInt(req.query.limit as string, 10);

  const page = Number.isInteger(rawPage) && rawPage > 0 ? rawPage : 1;
  let limit = Number.isInteger(rawLimit) && rawLimit > 0 ? rawLimit : defaultLimit;

  if (limit > maxLimit) {
    limit = maxLimit;
  }

  const offset = (page - 1) * limit;

  return { page, limit, offset };
}


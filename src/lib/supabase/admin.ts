import { createClient } from '@supabase/supabase-js';
import { requireSupabaseAdminEnv } from './env';

export function createSupabaseAdminClient() {
  const { supabaseUrl, supabaseServiceRoleKey } = requireSupabaseAdminEnv();

  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export interface SupabaseAuthAdminUserAttributes {
  email?: string;
  password?: string;
  email_confirm?: boolean;
  app_metadata?: Record<string, unknown>;
  user_metadata?: Record<string, unknown>;
}

interface SupabaseAuthAdminUser {
  id: string;
  email?: string | null;
}

interface SupabaseAuthAdminUserResponse {
  user?: SupabaseAuthAdminUser;
}

async function supabaseAuthAdminRequest<T>(path: string, init: RequestInit) {
  const { supabaseUrl, supabaseServiceRoleKey } = requireSupabaseAdminEnv();
  const response = await fetch(`${supabaseUrl}/auth/v1${path}`, {
    ...init,
    headers: {
      'content-type': 'application/json',
      apikey: supabaseServiceRoleKey,
      authorization: `Bearer ${supabaseServiceRoleKey}`,
      ...init.headers,
    },
  });
  const rawBody = await response.text();
  const payload = rawBody ? tryParseJson(rawBody) : null;

  if (!response.ok) {
    throw new Error(buildSupabaseAuthAdminError(response.status, payload, rawBody));
  }

  return payload as T;
}

function tryParseJson(value: string) {
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return null;
  }
}

function buildSupabaseAuthAdminError(status: number, payload: unknown, fallback: string) {
  if (payload && typeof payload === 'object') {
    const errorPayload = payload as Record<string, unknown>;
    const message =
      getString(errorPayload.message) ??
      getString(errorPayload.msg) ??
      getString(errorPayload.error_description) ??
      getString(errorPayload.error);

    if (message) {
      return `Supabase Auth admin request failed (${status}): ${message}`;
    }
  }

  return `Supabase Auth admin request failed (${status}): ${fallback || 'unknown error'}`;
}

function getString(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

export async function createSupabaseAuthAdminUser(attributes: SupabaseAuthAdminUserAttributes) {
  const response = await supabaseAuthAdminRequest<SupabaseAuthAdminUserResponse>(
    '/admin/users',
    {
      method: 'POST',
      body: JSON.stringify(attributes),
    },
  );
  const user = extractSupabaseAuthAdminUser(response);

  if (!user?.id) {
    throw new Error('Supabase Auth admin create user returned no user payload.');
  }

  return user;
}

export async function updateSupabaseAuthAdminUser(
  userId: string,
  attributes: SupabaseAuthAdminUserAttributes,
) {
  const response = await supabaseAuthAdminRequest<SupabaseAuthAdminUserResponse>(
    `/admin/users/${userId}`,
    {
      method: 'PUT',
      body: JSON.stringify(attributes),
    },
  );
  const user = extractSupabaseAuthAdminUser(response);

  if (!user?.id) {
    throw new Error('Supabase Auth admin update user returned no user payload.');
  }

  return user;
}

function extractSupabaseAuthAdminUser(payload: unknown) {
  if (payload && typeof payload === 'object') {
    const response = payload as SupabaseAuthAdminUserResponse & SupabaseAuthAdminUser;

    if (response.user?.id) {
      return response.user;
    }

    if (response.id) {
      return response;
    }
  }

  return null;
}

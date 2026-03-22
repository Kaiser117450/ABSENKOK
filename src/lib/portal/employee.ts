import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';

/** Typed employee context returned after a successful portal session resolution. */
export interface PortalEmployee {
  employee_id: string;
  employee_name: string;
  position: string | null;
  home_outlet_id: string | null;
  home_outlet_name: string | null;
  photo_url: string | null;
  active_badge_id: string | null;
}

/** Possible outcomes of an employee-context resolution attempt. */
export type ResolveResult =
  | { ok: true; employee: PortalEmployee }
  | { ok: false; reason: 'unauthenticated' | 'no_mapping' | 'rpc_error'; message: string };

/**
 * Resolve the authenticated employee context for the current portal request.
 *
 * This is the single server-side entry point for all portal pages that need
 * employee identity before rendering. Phase 38 schedule queries must call this
 * instead of performing their own identity join.
 *
 * Returns a typed result — never throws. Callers decide how to handle each
 * failure case (redirect, block render, etc.).
 */
export async function resolvePortalEmployee(Astro: AstroGlobal): Promise<ResolveResult> {
  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  // Validate the session server-side using getUser() (not getSession()) to
  // prevent trusting stale or spoofed client-side session state.
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) {
    return {
      ok: false,
      reason: 'unauthenticated',
      message: authError?.message ?? 'No active session.',
    };
  }

  // Call the backend resolver from plan 01.
  const { data, error: rpcError } = await supabase
    .rpc('resolve_portal_employee')
    .single();

  if (rpcError) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: rpcError.message,
    };
  }

  if (!data) {
    return {
      ok: false,
      reason: 'no_mapping',
      message: 'No active employee mapping found for this portal account.',
    };
  }

  const row = data as Record<string, unknown>;

  return {
    ok: true,
    employee: {
      employee_id: row['employee_id'] as string,
      employee_name: row['employee_name'] as string,
      position: (row['position'] as string | null) ?? null,
      home_outlet_id: (row['home_outlet_id'] as string | null) ?? null,
      home_outlet_name: (row['home_outlet_name'] as string | null) ?? null,
      photo_url: (row['photo_url'] as string | null) ?? null,
      active_badge_id: (row['active_badge_id'] as string | null) ?? null,
    },
  };
}

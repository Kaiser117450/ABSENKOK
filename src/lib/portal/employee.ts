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

type PortalLocals = {
  portalUser?: unknown | null;
};

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
  const locals = Astro.locals as PortalLocals;
  const hasPortalUser = Object.prototype.hasOwnProperty.call(locals, 'portalUser');
  const portalUser = locals.portalUser;

  if (!hasPortalUser || portalUser === null) {
    return {
      ok: false,
      reason: 'unauthenticated',
      message: 'No active session.',
    };
  }

  const supabase = createSupabaseServerClient(
    Astro.request.headers.get('cookie') ?? '',
    Astro.response.headers,
  );

  const { data, error } = await supabase.rpc('resolve_portal_employee');
  if (error) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: error.message,
    };
  }

  const employee = Array.isArray(data) ? (data[0] as PortalEmployee | undefined) : (data as PortalEmployee | null);
  if (!employee) {
    return {
      ok: false,
      reason: 'no_mapping',
      message: 'No active employee found for this portal account.',
    };
  }

  return {
    ok: true,
    employee,
  };
}

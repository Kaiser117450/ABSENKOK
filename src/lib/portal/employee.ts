import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import { createSupabaseAdminClient } from '../supabase/admin';

interface PortalEmployeeRow {
  id: string;
  name: string;
  position: string | null;
  home_outlet_id: string | null;
  photo_url: string | null;
  active_badge_id: string | null;
  is_active: boolean;
  archived_at: string | null;
}

interface OutletRow {
  id: string;
  name: string;
}

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

  const employeeId = user.app_metadata?.employee_id;
  const appRole = user.app_metadata?.app_role;
  if (typeof employeeId !== 'string' || employeeId.length === 0 || appRole !== 'employee_portal') {
    return {
      ok: false,
      reason: 'no_mapping',
      message: 'No active employee mapping found for this portal account.',
    };
  }

  const admin = createSupabaseAdminClient();
  const { data: employee, error: employeeError } = await admin
    .from('employees')
    .select('id, name, position, home_outlet_id, photo_url, active_badge_id, is_active, archived_at')
    .eq('id', employeeId)
    .single<PortalEmployeeRow>();

  if (employeeError) {
    return {
      ok: false,
      reason: 'rpc_error',
      message: employeeError.message,
    };
  }

  if (!employee || !employee.is_active || employee.archived_at !== null) {
    return {
      ok: false,
      reason: 'no_mapping',
      message: 'No active employee found for this portal account.',
    };
  }

  let homeOutletName: string | null = null;
  if (employee.home_outlet_id) {
    const { data: outlet, error: outletError } = await admin
      .from('outlets')
      .select('id, name')
      .eq('id', employee.home_outlet_id)
      .maybeSingle<OutletRow>();

    if (outletError) {
      return {
        ok: false,
        reason: 'rpc_error',
        message: outletError.message,
      };
    }

    homeOutletName = outlet?.name ?? null;
  }

  return {
    ok: true,
    employee: {
      employee_id: employee.id,
      employee_name: employee.name,
      position: employee.position ?? null,
      home_outlet_id: employee.home_outlet_id ?? null,
      home_outlet_name: homeOutletName,
      photo_url: employee.photo_url ?? null,
      active_badge_id: employee.active_badge_id ?? null,
    },
  };
}

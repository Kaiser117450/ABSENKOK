export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseAdminClient } from '../../../lib/supabase/admin';
import { normalizeSearchText, SEARCH_MIN_LENGTH, SEARCH_MAX_RESULTS } from '../../../lib/portal/auth';

export interface EmployeeSearchResult {
  employee_id: string;
  employee_name: string;
  home_outlet_id: string | null;
  home_outlet_name: string | null;
  position: string | null;
  photo_url: string | null;
  active_badge_id: string | null;
}

interface EmployeeRow {
  id: string;
  name: string;
  home_outlet_id: string | null;
  position: string | null;
  photo_url: string | null;
  active_badge_id: string | null;
}

interface OutletRow {
  id: string;
  name: string;
}

async function searchEmployeesByPattern(pattern: string) {
  const admin = createSupabaseAdminClient();
  const { data, error } = await admin
    .from('employees')
    .select(
      'id, name, home_outlet_id, position, photo_url, active_badge_id, employee_portal_accounts!inner(employee_id)',
    )
    .eq('is_active', true)
    .is('archived_at', null)
    .ilike('name', pattern)
    .order('name', { ascending: true })
    .limit(SEARCH_MAX_RESULTS)
    .returns<EmployeeRow[]>();

  if (error) {
    throw error;
  }

  return data ?? [];
}

export const GET: APIRoute = async ({ request }) => {
  const url = new URL(request.url);
  const rawQuery = url.searchParams.get('q') ?? '';
  const normalized = normalizeSearchText(rawQuery);

  if (normalized.length < SEARCH_MIN_LENGTH) {
    return new Response(JSON.stringify({ results: [] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const prefixMatches = await searchEmployeesByPattern(`${normalized}%`);
    const seenIds = new Set(prefixMatches.map((employee) => employee.id));
    let rows = prefixMatches;

    if (rows.length < SEARCH_MAX_RESULTS && normalized.length >= 3) {
      const fallbackMatches = await searchEmployeesByPattern(`%${normalized}%`);
      const remaining = fallbackMatches.filter((employee) => !seenIds.has(employee.id));
      rows = [...rows, ...remaining].slice(0, SEARCH_MAX_RESULTS);
    }

    const outletIds = Array.from(new Set(rows.map((employee) => employee.home_outlet_id).filter(Boolean))) as string[];
    const admin = createSupabaseAdminClient();
    const { data: outlets, error: outletsError } = outletIds.length === 0
      ? { data: [] as OutletRow[], error: null }
      : await admin
          .from('outlets')
          .select('id, name')
          .in('id', outletIds)
          .returns<OutletRow[]>();

    if (outletsError) {
      throw outletsError;
    }

    const outletMap = new Map((outlets ?? []).map((outlet) => [outlet.id, outlet.name]));
    const results: EmployeeSearchResult[] = rows.map((row) => ({
      employee_id: row.id,
      employee_name: row.name,
      home_outlet_id: row.home_outlet_id ?? null,
      home_outlet_name: row.home_outlet_id ? outletMap.get(row.home_outlet_id) ?? null : null,
      position: row.position ?? null,
      photo_url: row.photo_url ?? null,
      active_badge_id: row.active_badge_id ?? null,
    }));

    return new Response(JSON.stringify({ results }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'private, max-age=10',
      },
    });
  } catch (error) {
    console.error('[portal/auth/search] query error:', error);
    return new Response(JSON.stringify({ results: [] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};

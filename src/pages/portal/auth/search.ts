export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
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

  const cookieHeader = request.headers.get('cookie') ?? '';
  const supabase = createSupabaseServerClient(cookieHeader);

  const { data, error } = await supabase.rpc('search_portal_employees', {
    search_text: normalized,
    limit_count: SEARCH_MAX_RESULTS,
  });

  if (error) {
    console.error('[portal/auth/search] RPC error:', error.message);
    return new Response(JSON.stringify({ results: [] }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const results: EmployeeSearchResult[] = (data ?? []).map((row: EmployeeSearchResult) => ({
    employee_id: row.employee_id,
    employee_name: row.employee_name,
    home_outlet_id: row.home_outlet_id ?? null,
    home_outlet_name: row.home_outlet_name ?? null,
    position: row.position ?? null,
    photo_url: row.photo_url ?? null,
    active_badge_id: row.active_badge_id ?? null,
  }));

  return new Response(JSON.stringify({ results }), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      // Short private browser cache — avoids re-fetching for rapid back-edits.
      // max-age=10 is safe because the DB result set rarely changes mid-login.
      'Cache-Control': 'private, max-age=10',
    },
  });
};

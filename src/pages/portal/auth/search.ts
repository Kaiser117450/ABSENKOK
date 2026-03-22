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

  try {
    const supabase = createSupabaseServerClient(request.headers.get('cookie') ?? '');
    const { data, error } = await supabase.rpc('search_portal_employees', {
      search_text: normalized,
      limit_count: SEARCH_MAX_RESULTS,
    });

    if (error) {
      throw error;
    }

    const results = (Array.isArray(data) ? data : []) as EmployeeSearchResult[];

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

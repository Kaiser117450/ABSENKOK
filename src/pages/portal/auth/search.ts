export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
import {
  normalizeSearchText,
  SEARCH_MAX_QUERY_LENGTH,
  SEARCH_MAX_RESULTS,
  SEARCH_MIN_LENGTH,
} from '../../../lib/portal/auth';

export interface EmployeeSearchResult {
  employee_id: string;
  employee_name: string;
  home_outlet_name: string | null;
  position: string | null;
  photo_url: string | null;
}

const JSON_HEADERS = {
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
};

function emptyResultsResponse() {
  return new Response(JSON.stringify({ results: [] }), {
    status: 200,
    headers: JSON_HEADERS,
  });
}

function getOptionalString(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function mapEmployeeSearchResult(row: unknown): EmployeeSearchResult | null {
  if (!row || typeof row !== 'object') {
    return null;
  }

  const record = row as Record<string, unknown>;
  const employeeId = record.employee_id;
  const employeeName = record.employee_name;

  if (typeof employeeId !== 'string' || employeeId.length === 0) {
    return null;
  }

  if (typeof employeeName !== 'string' || employeeName.length === 0) {
    return null;
  }

  return {
    employee_id: employeeId,
    employee_name: employeeName,
    home_outlet_name: getOptionalString(record.home_outlet_name),
    position: getOptionalString(record.position),
    photo_url: getOptionalString(record.photo_url),
  };
}

export const GET: APIRoute = async ({ request }) => {
  const url = new URL(request.url);
  const rawQuery = url.searchParams.get('q') ?? '';
  const normalized = normalizeSearchText(rawQuery);

  if (
    normalized.length < SEARCH_MIN_LENGTH ||
    normalized.length > SEARCH_MAX_QUERY_LENGTH
  ) {
    return emptyResultsResponse();
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

    const results = Array.isArray(data)
      ? data
          .map(mapEmployeeSearchResult)
          .filter((result): result is EmployeeSearchResult => result !== null)
      : [];

    return new Response(JSON.stringify({ results }), {
      status: 200,
      headers: JSON_HEADERS,
    });
  } catch (error) {
    console.error('[portal/auth/search] query error:', error);
    return emptyResultsResponse();
  }
};

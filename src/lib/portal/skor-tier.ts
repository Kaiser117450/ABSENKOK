/**
 * Server-side data loaders for the admin Skor Tier page.
 *
 * Wraps the Phase 71 RPCs (`get_skor_tier_overview`, `get_employee_score_card`)
 * and applies sensible TypeScript types so pages stay typed end-to-end.
 *
 * RPCs are SECURITY DEFINER but apply their own outlet-scoping by reading
 * `app_metadata.app_role` / `managed_outlet_ids` from the caller's JWT —
 * therefore the SSR client (which carries the Supabase session cookie)
 * must be used here, never the service-role client.
 */

import type { AstroGlobal } from 'astro';
import { createSupabaseServerClient } from '../supabase/server';
import type { Tier } from './tier';

export interface SkorTierIcon {
  code: string;
  label: string;
  kind: 'achievement' | 'violation';
}

export interface SkorTierEmployeeRow {
  employee_id: string;
  employee_name: string;
  position: string | null;
  home_outlet_id: string | null;
  home_outlet_name: string | null;
  photo_url: string | null;
  employment_contract: 'FULLTIME' | 'PARTTIME' | null;
  is_new: boolean;
  tier: Tier;
  tier_capped_reason: 'new_employee' | 'parttime' | null;
  total_score: number | null;
  attendance_score: number | null;
  manual_score: number | null;
  qc_score: number | null;
  rank_outlet: number | null;
  rank_global: number | null;
  icons: SkorTierIcon[];
}

export interface ScoreCardNote {
  id: string;
  parent_id: string | null;
  author_name: string;
  author_role: string;
  body: string;
  created_at: string;
  updated_at: string | null;
}

export interface ScoreCardSummary {
  employee_id: string;
  period: string;
  attendance_score: number | null;
  manual_score: number | null;
  qc_score: number | null;
  total_score: number | null;
  tier: Tier | null;
  tier_capped_reason: string | null;
  rank_outlet: number | null;
  rank_global: number | null;
  computed_at: string;
}

export interface ScoreCard {
  employee: {
    id: string;
    name: string;
    position: string | null;
    home_outlet_id: string | null;
    employment_contract: 'FULLTIME' | 'PARTTIME' | null;
    created_at: string;
    is_new: boolean;
  };
  summary: ScoreCardSummary | null;
  icons: SkorTierIcon[];
  notes: ScoreCardNote[];
  period: string;
}

/**
 * Returns the current period in `YYYY-MM` format, evaluated in
 * Asia/Makassar so it matches what the Postgres function uses.
 */
export function getCurrentPeriod(): string {
  const formatter = new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Makassar',
    year: 'numeric',
    month: '2-digit',
  });
  return formatter.format(new Date()); // sv-SE → YYYY-MM
}

/**
 * Load the Skor Tier overview for the given period, scoped to the
 * caller's permissions (admin gets all, kepala/area get their outlets).
 * `outletId` filters within the caller's allowed outlets.
 */
export async function loadSkorTierOverview(
  Astro: AstroGlobal,
  options: { period?: string; outletId?: string | null } = {},
): Promise<{ rows: SkorTierEmployeeRow[]; period: string; error: string | null }> {
  const period = options.period ?? getCurrentPeriod();
  const cookieHeader = Astro.request.headers.get('cookie') ?? '';
  const supabase = createSupabaseServerClient(cookieHeader);

  const { data, error } = await supabase.rpc('get_skor_tier_overview', {
    p_period: period,
    p_outlet_id: options.outletId ?? null,
  });

  if (error) {
    console.error('[loadSkorTierOverview] RPC error', error);
    return { rows: [], period, error: error.message };
  }

  // RPC may return null when there's no data; coerce to empty list.
  const rows = (data ?? []) as SkorTierEmployeeRow[];
  return { rows, period, error: null };
}

/**
 * Load a single employee score card (summary + icons + threaded notes).
 */
export async function loadEmployeeScoreCard(
  Astro: AstroGlobal,
  employeeId: string,
  options: { period?: string } = {},
): Promise<{ card: ScoreCard | null; error: string | null }> {
  const period = options.period ?? getCurrentPeriod();
  const cookieHeader = Astro.request.headers.get('cookie') ?? '';
  const supabase = createSupabaseServerClient(cookieHeader);

  const { data, error } = await supabase.rpc('get_employee_score_card', {
    p_employee_id: employeeId,
    p_period: period,
  });

  if (error) {
    console.error('[loadEmployeeScoreCard] RPC error', error);
    return { card: null, error: error.message };
  }

  return { card: (data as ScoreCard) ?? null, error: null };
}

/**
 * Distinct outlets the caller has data for, derived from the rows.
 * Returned in stable name-asc order, with a synthetic `(Tanpa Outlet)`
 * entry for orphan employees.
 */
export function uniqueOutletsFromRows(
  rows: SkorTierEmployeeRow[],
): Array<{ id: string | null; name: string }> {
  const map = new Map<string | null, string>();
  for (const r of rows) {
    if (!map.has(r.home_outlet_id)) {
      map.set(r.home_outlet_id, r.home_outlet_name ?? '(Tanpa Outlet)');
    }
  }
  return Array.from(map.entries())
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

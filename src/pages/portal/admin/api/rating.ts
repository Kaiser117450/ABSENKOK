import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';
import { ADMIN_PORTAL_ROLES, getUserAppRole } from '../../../../lib/portal/auth';

// API endpoint must be SSR — uses session cookies for RLS-aware writes.
export const prerender = false;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PERIOD_RE = /^\d{4}-\d{2}$/;

/**
 * POST /portal/admin/api/rating
 *  - form-encoded:
 *      employee_id (required)
 *      aspect_id   (required)
 *      score       (required, numeric)
 *      rating_period (required, YYYY-MM)
 *      notes       (optional)
 *
 * Upserts an `employee_ratings` row for (employee_id, aspect_id, rated_by, period).
 * The `compute_employee_score` trigger handles tier/score recomputation.
 */
export const POST: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const supabase = createSupabaseServerClient(cookieHeader);

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const role = getUserAppRole(user);
  if (!role || !ADMIN_PORTAL_ROLES.has(role)) {
    return new Response('Forbidden', { status: 403 });
  }
  // Only admin and kepala_gerai may rate; area_supervisor is read-only here.
  if (role === 'area_supervisor') {
    return new Response('Area supervisor cannot create ratings', { status: 403 });
  }

  const form = await request.formData();
  const employeeId = String(form.get('employee_id') ?? '').trim();
  const aspectId = String(form.get('aspect_id') ?? '').trim();
  const period = String(form.get('rating_period') ?? '').trim();
  const scoreRaw = String(form.get('score') ?? '').trim();
  const notes = String(form.get('notes') ?? '').trim() || null;

  if (!UUID_RE.test(employeeId)) return new Response('Invalid employee_id', { status: 400 });
  if (!UUID_RE.test(aspectId)) return new Response('Invalid aspect_id', { status: 400 });
  if (!PERIOD_RE.test(period)) return new Response('Invalid rating_period', { status: 400 });

  const score = Number(scoreRaw);
  if (!Number.isFinite(score) || score < 0) {
    return new Response('Invalid score', { status: 400 });
  }

  // Look up the aspect to enforce the upper bound. The rating_aspects.max_score
  // column is the per-aspect ceiling (e.g. 5 for star ratings, 100 for percent
  // scores). Without this check an admin or kepala_gerai could submit an
  // arbitrary numeric value (e.g. 9999) which would then poison the weighted
  // average inside compute_employee_score.
  const { data: aspect, error: aspectError } = await supabase
    .from('rating_aspects')
    .select('max_score, is_active')
    .eq('id', aspectId)
    .maybeSingle<{ max_score: number; is_active: boolean }>();

  if (aspectError) {
    console.error('[POST /admin/api/rating] aspect lookup failed', aspectError);
    return new Response('Failed to validate aspect', { status: 500 });
  }
  if (!aspect || !aspect.is_active) {
    return new Response('Unknown or inactive aspect', { status: 400 });
  }
  if (score > aspect.max_score) {
    return new Response(
      `Score exceeds the maximum (${aspect.max_score}) for this aspect`,
      { status: 400 },
    );
  }

  // Upsert via the unique constraint on (employee_id, aspect_id, rated_by, rating_period).
  const { error } = await supabase.from('employee_ratings').upsert(
    {
      employee_id: employeeId,
      aspect_id: aspectId,
      rated_by: user.id,
      rater_role: role,
      score,
      notes,
      rating_period: period,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'employee_id,aspect_id,rated_by,rating_period' },
  );

  if (error) {
    console.error('[POST /admin/api/rating] upsert failed', error);
    return redirect(`/portal/admin/skor-tier/${employeeId}?notice=rating-error`, 303);
  }

  return redirect(`/portal/admin/skor-tier/${employeeId}?notice=rating-saved`, 303);
};

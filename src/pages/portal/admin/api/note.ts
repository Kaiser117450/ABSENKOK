import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';
import { ADMIN_PORTAL_ROLES, getUserAppRole } from '../../../../lib/portal/auth';

// API endpoint must be SSR — uses session cookies for RLS-aware writes.
export const prerender = false;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * POST /portal/admin/api/note
 *  - form-encoded: employee_id (required), body (required), parent_id (optional)
 *
 * Creates a threaded note (Reddit-style) on an employee's score page.
 * Returns a 303 redirect back to the detail page so the form submission
 * works without JS.
 */
export const POST: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const supabase = createSupabaseServerClient(cookieHeader);

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return new Response('Unauthorized', { status: 401 });
  }

  const role = getUserAppRole(user);
  if (!role || !ADMIN_PORTAL_ROLES.has(role)) {
    return new Response('Forbidden', { status: 403 });
  }

  // Parse form data (works for both application/x-www-form-urlencoded
  // and multipart/form-data which Astro normalises through Request.formData()).
  const form = await request.formData();
  const employeeId = String(form.get('employee_id') ?? '').trim();
  const parentId = String(form.get('parent_id') ?? '').trim() || null;
  const body = String(form.get('body') ?? '').trim();

  if (!UUID_RE.test(employeeId)) {
    return new Response('Invalid employee_id', { status: 400 });
  }
  if (parentId && !UUID_RE.test(parentId)) {
    return new Response('Invalid parent_id', { status: 400 });
  }
  if (body.length < 1 || body.length > 2000) {
    return new Response('Body must be 1-2000 chars', { status: 400 });
  }

  // Author display name: prefer the user's email local-part; admins
  // typically have a real email, kepala_gerai usually a generated one.
  const authorName =
    typeof user.user_metadata?.full_name === 'string' && user.user_metadata.full_name.length > 0
      ? user.user_metadata.full_name
      : (user.email ?? '').split('@')[0] || 'Admin';

  const { error } = await supabase.from('employee_rating_notes').insert({
    employee_id: employeeId,
    parent_id: parentId,
    author_id: user.id,
    author_name: authorName,
    author_role: role,
    body,
  });

  if (error) {
    console.error('[POST /admin/api/note] insert failed', error);
    return redirect(`/portal/admin/skor-tier/${employeeId}?notice=note-error`, 303);
  }

  return redirect(`/portal/admin/skor-tier/${employeeId}?notice=note-created`, 303);
};

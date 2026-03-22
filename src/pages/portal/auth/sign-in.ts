export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
import { buildPortalAuthEmail, buildPortalAuthPassword } from '../../../lib/portal/auth';

export const POST: APIRoute = async ({ request, redirect }) => {
  const formData = await request.formData();
  const employeeId = (formData.get('employee_id') ?? '').toString().trim();

  if (!employeeId) {
    return redirect('/portal/login?error=invalid', 302);
  }

  const authEmail = buildPortalAuthEmail(employeeId);
  const authPassword = buildPortalAuthPassword(employeeId);

  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  // Auto-provision the auth user if it doesn't exist (pre-confirmed, no email needed).
  const { error: provisionError } = await supabase.rpc('provision_portal_user', {
    p_employee_id: employeeId,
    p_email: authEmail,
    p_password: authPassword,
  });

  if (provisionError) {
    console.error('[portal/auth/sign-in] provision error:', provisionError.message);
    return redirect('/portal/login?error=invalid', 302);
  }

  // Sign in with the deterministic password.
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: authEmail,
    password: authPassword,
  });

  if (signInError) {
    console.error('[portal/auth/sign-in] sign-in error:', signInError.message);
    return redirect('/portal/login?error=invalid', 302);
  }

  // Flush Set-Cookie headers then redirect to the protected portal.
  const response = redirect('/portal', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

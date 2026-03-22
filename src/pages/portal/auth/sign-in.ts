export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
import { buildPortalAuthEmail } from '../../../lib/portal/auth';

export const POST: APIRoute = async ({ request, redirect }) => {
  const formData = await request.formData();
  const employeeId = (formData.get('employee_id') ?? '').toString().trim();
  const password = (formData.get('password') ?? '').toString();

  // Require a selected employee_id, not a free-form name.
  if (!employeeId || !password) {
    return redirect('/portal/login?error=invalid', 302);
  }

  // Build the hidden auth email from the stable employee UUID.
  const authEmail = buildPortalAuthEmail(employeeId);

  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  const { error } = await supabase.auth.signInWithPassword({
    email: authEmail,
    password,
  });

  if (error) {
    // Do not leak whether a name or account exists.
    return redirect('/portal/login?error=invalid', 302);
  }

  // Flush Set-Cookie headers then redirect to the protected portal.
  const response = redirect('/portal', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

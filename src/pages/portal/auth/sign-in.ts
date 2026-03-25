export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
import { buildPortalAuthEmail, buildPortalAuthPassword } from '../../../lib/portal/auth';
import { ensurePortalPasswordlessAccount } from '../../../lib/portal/provision';
import { hasSupabaseAdminEnv } from '../../../lib/supabase/env';

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

  let { error: signInError } = await supabase.auth.signInWithPassword({
    email: authEmail,
    password: authPassword,
  });

  if (signInError && hasSupabaseAdminEnv()) {
    try {
      await ensurePortalPasswordlessAccount(employeeId, authEmail, authPassword);
      const retry = await supabase.auth.signInWithPassword({
        email: authEmail,
        password: authPassword,
      });
      signInError = retry.error;
    } catch (provisionError) {
      console.error('[portal/auth/sign-in] passwordless provisioning error:', {
        employeeId,
        error: provisionError,
      });
      return redirect('/portal/login?error=invalid', 302);
    }
  }

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

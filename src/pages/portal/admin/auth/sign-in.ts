export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';
import { ADMIN_PORTAL_ROLES, getUserAppRole } from '../../../../lib/portal/auth';
import { checkRateLimit, getClientIp } from '../../../../lib/portal/rate-limit';
import { isTurnstileEnabled, verifyTurnstileToken } from '../../../../lib/portal/turnstile';

const SIGN_IN_RATE_LIMIT_MAX = 5;
const SIGN_IN_RATE_LIMIT_WINDOW_SECONDS = 60;

export const POST: APIRoute = async ({ request, redirect }) => {
  const rateLimit = await checkRateLimit(
    request,
    'admin_sign_in',
    SIGN_IN_RATE_LIMIT_MAX,
    SIGN_IN_RATE_LIMIT_WINDOW_SECONDS,
  );
  if (rateLimit && !rateLimit.allowed) {
    return redirect(
      `/portal/admin/login?error=rate_limited&retry_after=${rateLimit.retry_after}`,
      302,
    );
  }

  const formData = await request.formData();
  const email = (formData.get('email') ?? '').toString().trim();
  const password = (formData.get('password') ?? '').toString();

  if (!email || !password) {
    return redirect('/portal/admin/login?error=credentials', 302);
  }

  if (isTurnstileEnabled()) {
    const turnstileToken = (formData.get('cf-turnstile-response') ?? '').toString();
    const verification = await verifyTurnstileToken(turnstileToken, getClientIp(request));
    if (!verification.ok) {
      console.error('[portal/admin/auth/sign-in] turnstile verify failed', {
        email,
        reason: verification.reason,
      });
      return redirect('/portal/admin/login?error=turnstile', 302);
    }
  }

  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  const { data, error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (signInError || !data.user) {
    console.error('[portal/admin/auth/sign-in] sign-in error:', signInError?.message ?? 'no user');
    return redirect('/portal/admin/login?error=credentials', 302);
  }

  const role = getUserAppRole(data.user);
  if (!role || !ADMIN_PORTAL_ROLES.has(role)) {
    await supabase.auth.signOut({ scope: 'local' });
    return redirect('/portal/admin/login?error=unauthorized', 302);
  }

  const response = redirect('/portal/admin/skor-tier', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

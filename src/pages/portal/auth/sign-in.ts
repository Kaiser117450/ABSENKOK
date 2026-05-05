export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';
import { buildPortalAuthEmail, buildPortalAuthPassword } from '../../../lib/portal/auth';
import { ensurePortalPasswordlessAccount } from '../../../lib/portal/provision';
import { hasSupabaseAdminEnv } from '../../../lib/supabase/env';
import { checkRateLimit, getClientIp } from '../../../lib/portal/rate-limit';
import { isTurnstileEnabled, verifyTurnstileToken } from '../../../lib/portal/turnstile';

// 10 sign-in attempts per minute per IP. Tight enough to make
// credential-stuffing impractical while still tolerant of an entire
// outlet sharing one NAT (most outlets ≤ 20 employees, and only a few
// will retry within the same minute on a slow first attempt).
const SIGN_IN_RATE_LIMIT_MAX = 10;
const SIGN_IN_RATE_LIMIT_WINDOW_SECONDS = 60;

export const POST: APIRoute = async ({ request, redirect }) => {
  const rateLimit = await checkRateLimit(
    request,
    'portal_sign_in',
    SIGN_IN_RATE_LIMIT_MAX,
    SIGN_IN_RATE_LIMIT_WINDOW_SECONDS,
  );
  if (rateLimit && !rateLimit.allowed) {
    // The login form expects a redirect on failure (see login.astro
    // error handling). Surface the rate-limit reason via a query param
    // so the page can render a clear message.
    return redirect(
      `/portal/login?error=rate_limited&retry_after=${rateLimit.retry_after}`,
      302,
    );
  }

  const formData = await request.formData();
  const employeeId = (formData.get('employee_id') ?? '').toString().trim();

  if (!employeeId) {
    return redirect('/portal/login?error=invalid', 302);
  }

  // Cloudflare Turnstile gating. When the secret key is configured we
  // require a valid token; otherwise the check is bypassed (so local dev
  // and preview deploys without Turnstile still work).
  if (isTurnstileEnabled()) {
    const turnstileToken = (formData.get('cf-turnstile-response') ?? '').toString();
    const verification = await verifyTurnstileToken(turnstileToken, getClientIp(request));
    if (!verification.ok) {
      console.error('[portal/auth/sign-in] turnstile verify failed', {
        employeeId,
        reason: verification.reason,
      });
      return redirect('/portal/login?error=turnstile', 302);
    }
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

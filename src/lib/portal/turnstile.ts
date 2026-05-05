/**
 * Cloudflare Turnstile token verification.
 *
 * Activation is gated on `TURNSTILE_SECRET_KEY`: when the secret is not
 * set in the environment, verification is *skipped* (returns true). This
 * lets the same code path work on local dev / preview deploys where the
 * widget is not configured, while production fails closed once the
 * secret is provisioned.
 */

const TURNSTILE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

interface TurnstileResponse {
  success: boolean;
  'error-codes'?: string[];
  challenge_ts?: string;
  hostname?: string;
  action?: string;
}

/** Whether Turnstile verification is currently active in this environment. */
export function isTurnstileEnabled(): boolean {
  const secret = import.meta.env.TURNSTILE_SECRET_KEY;
  return typeof secret === 'string' && secret.length > 0;
}

/**
 * Verify a Turnstile token against Cloudflare. When Turnstile is not
 * enabled (no secret in env), skips verification and returns true.
 *
 * @param token the value of the `cf-turnstile-response` form field
 * @param remoteIp optional client IP — Cloudflare will compare against
 *                 the IP that solved the challenge
 */
export async function verifyTurnstileToken(
  token: string | null | undefined,
  remoteIp?: string,
): Promise<{ ok: boolean; reason?: string }> {
  const secret = import.meta.env.TURNSTILE_SECRET_KEY;

  if (typeof secret !== 'string' || secret.length === 0) {
    // Not configured → bypass. Production deploys MUST set this env var.
    return { ok: true, reason: 'turnstile_not_configured' };
  }

  if (!token) {
    return { ok: false, reason: 'missing_token' };
  }

  const body = new URLSearchParams();
  body.set('secret', secret);
  body.set('response', token);
  if (remoteIp && remoteIp !== 'unknown') {
    body.set('remoteip', remoteIp);
  }

  let response: Response;
  try {
    response = await fetch(TURNSTILE_VERIFY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
  } catch (err) {
    console.error('[turnstile] network error verifying token', err);
    // Fail closed — if we cannot reach Cloudflare we should not let the
    // request through. The login page is allowed to retry.
    return { ok: false, reason: 'verify_network_error' };
  }

  if (!response.ok) {
    return { ok: false, reason: `verify_http_${response.status}` };
  }

  const data = (await response.json()) as TurnstileResponse;
  if (!data.success) {
    return {
      ok: false,
      reason: `cf_${(data['error-codes'] ?? []).join(',') || 'unknown'}`,
    };
  }
  return { ok: true };
}

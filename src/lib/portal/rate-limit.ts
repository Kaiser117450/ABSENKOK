import { createSupabaseAdminClient } from '../supabase/admin';

/**
 * Result returned by the Postgres `check_and_increment_rate_limit` RPC.
 */
export interface RateLimitResult {
  allowed: boolean;
  count: number;
  limit: number;
  window_start: string;
  retry_after: number;
}

/**
 * Pull the caller's IP from the standard Vercel/Cloudflare proxy headers.
 *
 * Falls back to `unknown` when no proxy header is present (local dev,
 * direct invocation, etc) — that means all unattributed traffic shares
 * one bucket, which is fine: the worst case is a slightly stricter
 * bucket on local dev, not a security gap.
 */
export function getClientIp(request: Request): string {
  const fwd = request.headers.get('x-forwarded-for');
  if (fwd) {
    // x-forwarded-for is a comma-separated list `<client>, <proxy1>, …`.
    // We want the leftmost entry, which is the original client.
    const first = fwd.split(',')[0]?.trim();
    if (first) return first;
  }
  const real = request.headers.get('x-real-ip');
  if (real) return real.trim();
  const cf = request.headers.get('cf-connecting-ip');
  if (cf) return cf.trim();
  return 'unknown';
}

/**
 * Check the per-IP rate limit for the given endpoint and increment the
 * counter atomically. Returns null if the rate-limit check itself failed
 * (which we treat as fail-open — a temporarily unavailable counter
 * should not lock honest users out).
 */
export async function checkRateLimit(
  request: Request,
  endpoint: 'portal_search' | 'portal_sign_in' | 'admin_sign_in',
  maxRequests: number,
  windowSeconds: number,
): Promise<RateLimitResult | null> {
  const ip = getClientIp(request);

  try {
    // Must use the service-role client. The RPC is granted only to
    // service_role precisely so the public anon key cannot be used to call
    // it from the browser with a spoofed `p_ip` to lock out a victim.
    const supabase = createSupabaseAdminClient();
    const { data, error } = await supabase.rpc('check_and_increment_rate_limit', {
      p_ip: ip,
      p_endpoint: endpoint,
      p_max_requests: maxRequests,
      p_window_seconds: windowSeconds,
    });

    if (error) {
      console.error('[rate-limit] RPC error', { endpoint, error: error.message });
      return null; // fail-open
    }

    if (!data || typeof data !== 'object') {
      return null;
    }

    return data as unknown as RateLimitResult;
  } catch (err) {
    console.error('[rate-limit] unexpected error', { endpoint, err });
    return null;
  }
}

/**
 * Build a 429 Too Many Requests response with the standard `Retry-After`
 * header. Caller decides JSON-vs-redirect shape.
 */
export function buildRateLimitJsonResponse(retryAfterSeconds: number): Response {
  return new Response(
    JSON.stringify({
      error: 'rate_limited',
      message: 'Terlalu banyak percobaan. Silakan tunggu sebentar dan coba lagi.',
      retry_after: retryAfterSeconds,
    }),
    {
      status: 429,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-store',
        'Retry-After': String(Math.max(retryAfterSeconds, 1)),
      },
    },
  );
}

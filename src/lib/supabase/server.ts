import { createServerClient, parseCookieHeader, serializeCookieHeader } from '@supabase/ssr';
import { requireSupabaseServerEnv } from './env';
/** Build an SSR-safe Supabase client from request cookie header string. */
export function createSupabaseServerClient(
  requestCookieHeader: string,
  responseHeaders: Headers | null = null,
) {
  const { supabaseUrl, supabaseAnonKey } = requireSupabaseServerEnv();

  return createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return parseCookieHeader(requestCookieHeader)
          .filter((c): c is { name: string; value: string } => c.value !== undefined);
      },
      setAll(cookies) {
        if (responseHeaders) {
          cookies.forEach(({ name, value, options }) => {
            responseHeaders.append(
              'Set-Cookie',
              serializeCookieHeader(name, value, options),
            );
          });
        }
      },
    },
  });
}

import { createServerClient, parseCookieHeader, serializeCookieHeader } from '@supabase/ssr';
/** Build an SSR-safe Supabase client from request cookie header string. */
export function createSupabaseServerClient(
  requestCookieHeader: string,
  responseHeaders: Headers | null = null,
) {
  const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY environment variables.',
    );
  }

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

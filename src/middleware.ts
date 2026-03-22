import { defineMiddleware } from 'astro:middleware';
import { createServerClient, parseCookieHeader, serializeCookieHeader } from '@supabase/ssr';
import { isProtectedPortalRoute } from './lib/portal/auth';
import { getSupabaseServerEnv } from './lib/supabase/env';

export const onRequest = defineMiddleware(async (context, next) => {
  const { url, request, redirect } = context;
  const pathname = url.pathname;

  // Only apply portal logic for /portal paths.
  // Marketing routes skip this entirely.
  if (!pathname.startsWith('/portal')) {
    return next();
  }

  const { supabaseUrl, supabaseAnonKey } = getSupabaseServerEnv();

  if (!supabaseUrl || !supabaseAnonKey) {
    // Missing env vars — let the page handle it; don't block marketing.
    return next();
  }

  // Collect cookies from request.
  const cookieHeader = request.headers.get('cookie') ?? '';

  // Accumulate Set-Cookie headers from Supabase SSR refresh.
  const newCookies: string[] = [];

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return parseCookieHeader(cookieHeader)
          .filter((c): c is { name: string; value: string } => c.value !== undefined);
      },
      setAll(cookies) {
        cookies.forEach(({ name, value, options }) => {
          newCookies.push(serializeCookieHeader(name, value, options));
        });
      },
    },
  });

  // Refresh session and propagate new cookies.
  // Use getUser() — Supabase SSR docs recommend getUser() for server-side
  // protected route validation instead of getSession().
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Forward to the route handler.
  const response = await next();

  // Attach any refreshed auth cookies to the response.
  newCookies.forEach((cookie) => {
    response.headers.append('Set-Cookie', cookie);
  });

  // Enforce auth on protected portal routes.
  if (isProtectedPortalRoute(pathname) && !user) {
    return redirect('/portal/login', 302);
  }

  return response;
});

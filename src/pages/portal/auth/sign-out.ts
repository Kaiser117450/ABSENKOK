export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';

export const POST: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  // AUTH-04: local scope — ends only the portal session, not the global Supabase session.
  // The installed auth-js default is 'global'; we must be explicit here.
  await supabase.auth.signOut({ scope: 'local' });

  const response = redirect('/portal/login?signed_out=1', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

// Also support GET for simple link-based sign-out.
export const GET: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  // AUTH-04: local scope — same contract as POST.
  await supabase.auth.signOut({ scope: 'local' });

  const response = redirect('/portal/login?signed_out=1', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

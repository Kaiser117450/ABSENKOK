export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../lib/supabase/server';

export const POST: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  await supabase.auth.signOut();

  const response = redirect('/portal/login', 302);
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

  await supabase.auth.signOut();

  const response = redirect('/portal/login', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

export const prerender = false;

import type { APIRoute } from 'astro';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const POST: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  await supabase.auth.signOut({ scope: 'local' });

  const response = redirect('/portal/admin/login?signed_out=1', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

export const GET: APIRoute = async ({ request, redirect }) => {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const responseHeaders = new Headers();
  const supabase = createSupabaseServerClient(cookieHeader, responseHeaders);

  await supabase.auth.signOut({ scope: 'local' });

  const response = redirect('/portal/admin/login?signed_out=1', 302);
  responseHeaders.forEach((value, key) => {
    response.headers.append(key, value);
  });
  return response;
};

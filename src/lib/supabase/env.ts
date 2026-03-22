const supabaseUrl =
  import.meta.env.SUPABASE_URL ?? import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey =
  import.meta.env.SUPABASE_ANON_KEY ?? import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
const supabaseServiceRoleKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;

export function getSupabaseServerEnv() {
  return {
    supabaseUrl,
    supabaseAnonKey,
  };
}

export function requireSupabaseServerEnv() {
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables. PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY are also accepted as a fallback.',
    );
  }

  return {
    supabaseUrl,
    supabaseAnonKey,
  };
}

export function hasSupabaseAdminEnv() {
  return Boolean(supabaseUrl && supabaseServiceRoleKey);
}

export function requireSupabaseAdminEnv() {
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables for server-side portal provisioning.',
    );
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
  };
}

const supabaseUrl =
  import.meta.env.SUPABASE_URL ?? import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey =
  import.meta.env.SUPABASE_ANON_KEY ?? import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

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

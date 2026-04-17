import { createClient } from '@supabase/supabase-js';
import { requireSupabaseServerEnv } from './env';

export function createSupabasePublicClient() {
  const { supabaseUrl, supabaseAnonKey } = requireSupabaseServerEnv();

  return createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

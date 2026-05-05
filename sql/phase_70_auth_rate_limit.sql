-- =============================================================================
-- Phase 70 — Auth rate limiting (Postgres-backed)
-- =============================================================================
--
-- Backs the rate-limit guard for the two anonymous portal endpoints:
--   /portal/auth/search   — 20 req/min per IP
--   /portal/auth/sign-in  — 10 req/min per IP
--
-- Keeping the counter inside Postgres avoids introducing a new vendor
-- (Upstash / Vercel KV) for what is, in practice, a very low-volume hot
-- path: ~100 employees × peak 1 attempt/sec ≪ Postgres can absorb. The
-- function is `SECURITY DEFINER` so the anon Astro server client (which
-- only has the role `anon` at the Supabase gateway) can call it without
-- being granted insert/update on the underlying table.
--
-- Trade-offs vs Redis:
--   + No new infra, no new env vars, no new bill.
--   + Counters are durable across deploy/region restarts.
--   - One extra DB round-trip per anonymous request (single-row upsert,
--     ~1ms p50 on the same region).
--   - Window granularity is per minute (not sliding), which is fine for
--     human brute-force defence; not designed for sub-second bursts.
--
-- Idempotent: safe to re-run.
-- =============================================================================

-- 1) The state table. (ip, endpoint, window_start) is the natural key.
create table if not exists public.auth_rate_limit_state (
  ip            text        not null,
  endpoint      text        not null,
  window_start  timestamptz not null,
  count         int         not null default 0,
  primary key (ip, endpoint, window_start)
);

-- Used by the periodic cleanup function below so old rows do not bloat
-- the table forever.
create index if not exists auth_rate_limit_state_window_idx
  on public.auth_rate_limit_state (window_start);

-- The table is internal — anon/authenticated should never hit it
-- directly.
alter table public.auth_rate_limit_state enable row level security;

-- No policies => no access for anon/authenticated. Only service_role and
-- the SECURITY DEFINER function below can touch it.

-- 2) Atomic check-and-increment RPC.
--
-- Returns:
--   {
--     allowed:        bool,   -- false when count would exceed limit
--     count:          int,    -- new value after this request
--     limit:          int,    -- echoed input
--     window_start:   timestamptz,
--     retry_after:    int     -- seconds until next window opens
--   }
--
-- Note: we always increment even when over the limit so that abusive
-- callers continue to see "denied" instead of being able to game the
-- counter by issuing exactly `p_max_requests` attempts and then waiting.
create or replace function public.check_and_increment_rate_limit(
  p_ip              text,
  p_endpoint        text,
  p_max_requests    int,
  p_window_seconds  int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window_start timestamptz;
  v_count        int;
  v_now          timestamptz := now();
  v_window_end   timestamptz;
  v_retry_after  int;
begin
  if p_max_requests <= 0 or p_window_seconds <= 0 then
    raise exception 'check_and_increment_rate_limit: invalid limit or window';
  end if;

  -- Snap `now()` down to the start of the current fixed window. Using a
  -- fixed window (not sliding) because the writes are O(1) per request
  -- and we don't need millisecond accuracy for human brute-force.
  v_window_start := to_timestamp(
    floor(extract(epoch from v_now) / p_window_seconds) * p_window_seconds
  );
  v_window_end   := v_window_start + (p_window_seconds || ' seconds')::interval;

  insert into public.auth_rate_limit_state (ip, endpoint, window_start, count)
  values (coalesce(p_ip, 'unknown'), p_endpoint, v_window_start, 1)
  on conflict (ip, endpoint, window_start) do update
    set count = public.auth_rate_limit_state.count + 1
  returning count into v_count;

  v_retry_after := greatest(0, ceil(extract(epoch from (v_window_end - v_now))))::int;

  return jsonb_build_object(
    'allowed',      v_count <= p_max_requests,
    'count',        v_count,
    'limit',        p_max_requests,
    'window_start', v_window_start,
    'retry_after',  v_retry_after
  );
end;
$$;

-- Restrict the RPC to the service_role.
--
-- Earlier revisions granted execute to anon + authenticated so the Astro
-- server's anon client could call it directly. That created a targeted-DoS
-- vector: an attacker holding the public anon key could call the RPC via
-- PostgREST with a victim's IP in `p_ip` and `p_max_requests = 1`, racing
-- the counter past the legitimate limit and locking the victim out for a
-- whole minute. PostgREST honours the granted role's permissions, so the
-- only safe answer is to make this RPC service-role-only and proxy it
-- from a server-side handler that has the service-role key (which is
-- never shipped to the browser). See src/lib/portal/rate-limit.ts.
revoke execute on function public.check_and_increment_rate_limit(text, text, int, int)
  from public, anon, authenticated;
grant execute on function public.check_and_increment_rate_limit(text, text, int, int)
  to service_role;

-- 3) Cleanup helper — schedule from pg_cron or a Supabase scheduled
-- function. Not auto-scheduled here; the table stays small even without
-- it (one row per (ip, endpoint, minute)).
create or replace function public.cleanup_auth_rate_limit_state()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted int;
begin
  delete from public.auth_rate_limit_state
   where window_start < now() - interval '1 hour';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

grant execute on function public.cleanup_auth_rate_limit_state()
  to service_role;

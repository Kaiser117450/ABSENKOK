-- =============================================================================
-- Phase 71 — Employee Scoring System (tier SSS-F + manual + QC + threaded notes)
-- =============================================================================
--
-- Adds five tables, the compute RPC, RLS, a refresh trigger, and the realtime
-- publication needed for the Astro `/portal/admin/skor-tier` UI to render a
-- live "good/bad employee" hierarchy. Idempotent — safe to re-run.
--
-- Score model
--   total = w_attendance · attendance_score
--         + w_manual     · manual_score
--         + w_qc         · qc_score
--   (re-normalised when one component is missing so unrated employees still
--    get a representative score from attendance only)
--
-- Tier ladder
--   SSS  ≥ 95   |  SS  ≥ 90  |  S  ≥ 85
--   A    ≥ 75   |  B   ≥ 65  |  C  ≥ 55  |  D  ≥ 40  |  F  < 40
--
-- Tier caps (set even if score qualifies for higher)
--   • new_employee  → registered within last 7 days  → max A
--   • parttime      → employment_contract = 'PARTTIME' → max A
--
-- Realtime
--   `employee_score_summary` is added to the `supabase_realtime` publication
--   so the Astro client (using anon key + RLS) gets push updates whenever a
--   rating triggers `compute_employee_score`.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1) rating_aspects — definisi aspek penilaian
-- ----------------------------------------------------------------------------
create table if not exists public.rating_aspects (
  id            uuid        primary key default gen_random_uuid(),
  code          text        not null unique,
  display_name  text        not null,
  category      text        not null check (category in ('manual', 'qc')),
  weight        numeric     not null default 1.0 check (weight >= 0),
  max_score     numeric     not null default 5.0 check (max_score > 0),
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists rating_aspects_active_idx
  on public.rating_aspects (category, is_active);

-- ----------------------------------------------------------------------------
-- 2) employee_ratings — entri rating individual (per rater × aspek × bulan)
-- ----------------------------------------------------------------------------
create table if not exists public.employee_ratings (
  id              uuid        primary key default gen_random_uuid(),
  employee_id     uuid        not null
                              references public.employees(id) on delete cascade,
  aspect_id       uuid        not null
                              references public.rating_aspects(id) on delete restrict,
  rated_by        uuid,       -- auth.users(id) — nullable for QC system feeds
  rater_role      text        not null
                              check (rater_role in ('admin', 'kepala_gerai', 'qc_system')),
  score           numeric     not null,
  notes           text,
  rating_period   text        not null  -- YYYY-MM
                              check (rating_period ~ '^\d{4}-\d{2}$'),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- One rater can leave at most one rating per (aspect, period) per employee.
  -- Different raters can each leave their own rating; the compute RPC averages
  -- across raters of the same role.
  unique (employee_id, aspect_id, rated_by, rating_period)
);

create index if not exists employee_ratings_employee_period_idx
  on public.employee_ratings (employee_id, rating_period);
create index if not exists employee_ratings_aspect_idx
  on public.employee_ratings (aspect_id);

-- ----------------------------------------------------------------------------
-- 3) score_weight_config — bobot per periode (default applied when no row)
-- ----------------------------------------------------------------------------
create table if not exists public.score_weight_config (
  period              text        primary key
                                  check (period ~ '^\d{4}-\d{2}$'),
  weight_attendance   numeric     not null default 0.50 check (weight_attendance >= 0),
  weight_manual       numeric     not null default 0.30 check (weight_manual     >= 0),
  weight_qc           numeric     not null default 0.20 check (weight_qc         >= 0),
  updated_at          timestamptz not null default now(),
  -- Sum must be ≈ 1 (allow small float fudge)
  check (
    abs((weight_attendance + weight_manual + weight_qc) - 1.0) < 0.001
  )
);

-- ----------------------------------------------------------------------------
-- 4) employee_score_summary — agregat cache + tier
-- ----------------------------------------------------------------------------
create table if not exists public.employee_score_summary (
  employee_id         uuid        not null
                                  references public.employees(id) on delete cascade,
  period              text        not null
                                  check (period ~ '^\d{4}-\d{2}$'),
  attendance_score    numeric,    -- 0-100 derived from strict recap
  manual_score        numeric,    -- 0-100 weighted average of manual aspects
  qc_score            numeric,    -- 0-100 weighted average of QC aspects
  total_score         numeric,    -- 0-100
  tier                text        check (tier in ('SSS','SS','S','A','B','C','D','F')),
  tier_capped_reason  text        check (tier_capped_reason in ('new_employee','parttime') or tier_capped_reason is null),
  rank_outlet         int,        -- rank within home_outlet (1 = best)
  rank_global         int,        -- rank across all outlets
  computed_at         timestamptz not null default now(),
  primary key (employee_id, period)
);

create index if not exists employee_score_summary_period_idx
  on public.employee_score_summary (period, total_score desc);
create index if not exists employee_score_summary_tier_idx
  on public.employee_score_summary (period, tier);

-- ----------------------------------------------------------------------------
-- 5) employee_rating_notes — Reddit-style threaded comments (admin/kepala only)
-- ----------------------------------------------------------------------------
create table if not exists public.employee_rating_notes (
  id            uuid        primary key default gen_random_uuid(),
  employee_id   uuid        not null
                            references public.employees(id) on delete cascade,
  parent_id     uuid        references public.employee_rating_notes(id) on delete cascade,
  author_id     uuid,       -- auth.users(id)
  author_name   text        not null,   -- denormalised snapshot
  author_role   text        not null
                            check (author_role in ('admin', 'kepala_gerai', 'area_supervisor')),
  body          text        not null check (length(body) between 1 and 2000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz,
  deleted_at    timestamptz             -- soft delete
);

create index if not exists employee_rating_notes_employee_idx
  on public.employee_rating_notes (employee_id, created_at desc);
create index if not exists employee_rating_notes_parent_idx
  on public.employee_rating_notes (parent_id);

-- ----------------------------------------------------------------------------
-- 6) RLS
-- ----------------------------------------------------------------------------
alter table public.rating_aspects          enable row level security;
alter table public.employee_ratings        enable row level security;
alter table public.score_weight_config     enable row level security;
alter table public.employee_score_summary  enable row level security;
alter table public.employee_rating_notes   enable row level security;

-- Helper: is the caller an admin or kepala_gerai who can manage `p_outlet_id`?
-- Reuses the Phase 51 helper if it exists, otherwise inlines the check.
create or replace function public.score_caller_can_access_outlet(p_outlet_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text := nullif(btrim(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_managed_outlet_text text := nullif(btrim(auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id'), '');
  v_managed_outlet_id uuid;
  v_managed_outlet_ids uuid[] := array[]::uuid[];
  v_candidate text;
begin
  if v_role is null then
    return false;
  end if;
  if v_role = 'admin' then
    return true;
  end if;
  if v_role not in ('kepala_gerai', 'area_supervisor') then
    return false;
  end if;

  -- Legacy single-outlet field
  if v_managed_outlet_text is not null
     and v_managed_outlet_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_managed_outlet_ids := array_append(v_managed_outlet_ids, v_managed_outlet_text::uuid);
  end if;

  -- New multi-outlet field
  if jsonb_typeof(auth.jwt() -> 'app_metadata' -> 'managed_outlet_ids') = 'array' then
    for v_candidate in
      select jsonb_array_elements_text(auth.jwt() -> 'app_metadata' -> 'managed_outlet_ids')
    loop
      if v_candidate ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
        v_managed_outlet_ids := array_append(v_managed_outlet_ids, v_candidate::uuid);
      end if;
    end loop;
  end if;

  return p_outlet_id = any(v_managed_outlet_ids);
end;
$$;

grant execute on function public.score_caller_can_access_outlet(uuid)
  to authenticated;

-- rating_aspects — admin write, others read
drop policy if exists "rating_aspects_admin_all" on public.rating_aspects;
create policy "rating_aspects_admin_all" on public.rating_aspects
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

drop policy if exists "rating_aspects_staff_select" on public.rating_aspects;
create policy "rating_aspects_staff_select" on public.rating_aspects
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') in ('admin', 'kepala_gerai', 'area_supervisor'));

-- score_weight_config — admin only
drop policy if exists "score_weight_config_admin_all" on public.score_weight_config;
create policy "score_weight_config_admin_all" on public.score_weight_config
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

drop policy if exists "score_weight_config_staff_select" on public.score_weight_config;
create policy "score_weight_config_staff_select" on public.score_weight_config
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') in ('admin', 'kepala_gerai', 'area_supervisor'));

-- employee_ratings — admin all, kepala_gerai/area_supervisor scoped to their outlets
drop policy if exists "employee_ratings_admin_all" on public.employee_ratings;
create policy "employee_ratings_admin_all" on public.employee_ratings
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

drop policy if exists "employee_ratings_outlet_scoped" on public.employee_ratings;
create policy "employee_ratings_outlet_scoped" on public.employee_ratings
  for all
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and exists (
      select 1 from public.employees e
       where e.id = employee_ratings.employee_id
         and public.score_caller_can_access_outlet(e.home_outlet_id)
    )
  )
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and exists (
      select 1 from public.employees e
       where e.id = employee_ratings.employee_id
         and public.score_caller_can_access_outlet(e.home_outlet_id)
    )
  );

-- employee_score_summary — read-only via RLS; writes happen via SECURITY
-- DEFINER RPC `compute_employee_score` so application code never needs
-- direct INSERT/UPDATE permission.
drop policy if exists "employee_score_summary_admin_select" on public.employee_score_summary;
create policy "employee_score_summary_admin_select" on public.employee_score_summary
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

drop policy if exists "employee_score_summary_outlet_select" on public.employee_score_summary;
create policy "employee_score_summary_outlet_select" on public.employee_score_summary
  for select
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and exists (
      select 1 from public.employees e
       where e.id = employee_score_summary.employee_id
         and public.score_caller_can_access_outlet(e.home_outlet_id)
    )
  );

-- employee_rating_notes — admin all, kepala_gerai/area_supervisor scoped
drop policy if exists "employee_rating_notes_admin_all" on public.employee_rating_notes;
create policy "employee_rating_notes_admin_all" on public.employee_rating_notes
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin');

drop policy if exists "employee_rating_notes_outlet_select" on public.employee_rating_notes;
create policy "employee_rating_notes_outlet_select" on public.employee_rating_notes
  for select
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and exists (
      select 1 from public.employees e
       where e.id = employee_rating_notes.employee_id
         and public.score_caller_can_access_outlet(e.home_outlet_id)
    )
  );

drop policy if exists "employee_rating_notes_outlet_insert" on public.employee_rating_notes;
create policy "employee_rating_notes_outlet_insert" on public.employee_rating_notes
  for insert
  to authenticated
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and exists (
      select 1 from public.employees e
       where e.id = employee_rating_notes.employee_id
         and public.score_caller_can_access_outlet(e.home_outlet_id)
    )
  );

drop policy if exists "employee_rating_notes_own_update" on public.employee_rating_notes;
create policy "employee_rating_notes_own_update" on public.employee_rating_notes
  for update
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and author_id = auth.uid()
  )
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') in ('kepala_gerai', 'area_supervisor')
    and author_id = auth.uid()
  );

-- ----------------------------------------------------------------------------
-- 7) compute_employee_score — main scoring RPC
-- ----------------------------------------------------------------------------
--
-- Algoritma:
--   1. Ambil counters dari Phase 57 strict recap (via get_site_leaderboard untuk
--      bulan yang sesuai dengan p_period).
--   2. Convert counters → attendance_score 0..100.
--   3. Aggregate manual + qc ratings (rata-rata weighted by aspect.weight,
--      normalised ke 0-100 dengan max_score per aspek).
--   4. Total = weighted sum dari komponen yang ADA (renormalised).
--   5. Map total → tier; apply caps (new_employee, parttime).
--   6. Upsert ke employee_score_summary, recompute rank.
--
-- Returns the upserted summary row as JSONB.
create or replace function public.compute_employee_score(
  p_employee_id  uuid,
  p_period       text default to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM')
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee record;
  -- NULL by default so the renormalisation logic can detect missing data.
  -- Initialising to 0 caused the formula to silently produce 100 for any
  -- (employee, period) combination that lacked a leaderboard row, which
  -- in turn corrupted historical periods and zero-scan employees with a
  -- bogus "perfect attendance" score.
  v_late_count int;
  v_absence_count int;
  v_short_work_count int;
  v_excess_break_count int;
  v_unresolved_count int;
  v_safe_days int;

  v_attendance_score numeric;
  v_manual_score numeric;
  v_qc_score numeric;
  v_total_score numeric;

  v_w_att numeric;
  v_w_man numeric;
  v_w_qc numeric;
  v_w_sum numeric;

  v_tier text;
  v_capped text;

  v_is_new boolean;
  v_is_parttime boolean;

  v_summary record;
begin
  select id, home_outlet_id, employment_contract, created_at
    into v_employee
    from public.employees
   where id = p_employee_id;

  if not found then
    raise exception 'compute_employee_score: employee % not found', p_employee_id;
  end if;

  v_is_new := v_employee.created_at >= (now() - interval '7 days');
  v_is_parttime := v_employee.employment_contract = 'PARTTIME';

  -- ------------------------------------------------------------------
  -- attendance_score from strict recap (Phase 57)
  -- ------------------------------------------------------------------
  -- get_site_leaderboard returns one row per employee for the calendar
  -- month containing today. For non-current `p_period` we currently only
  -- recompute when caller asks for the current month; older months use
  -- whatever was last stored. This is acceptable: tier history snapshots
  -- are a future-phase concern.
  --
  -- attendance_score stays NULL when:
  --   • caller asked for a non-current period (we don't backfill history), OR
  --   • the leaderboard row is missing for this employee (no scans yet,
  --     or freshly registered without any logs).
  -- The renormalisation block below then zeroes out the attendance weight
  -- so the total falls back to whatever manual/qc data exists.
  if p_period = to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM') then
    select late_count, absence_count, short_work_count, excess_break_count,
           unresolved_count, safe_days
      into v_late_count, v_absence_count, v_short_work_count,
           v_excess_break_count, v_unresolved_count, v_safe_days
      from public.get_site_leaderboard()
     where employee_id = p_employee_id;

    if found then
      v_attendance_score := greatest(0, least(100,
          100
        - (3 * coalesce(v_late_count, 0))
        - (5 * coalesce(v_absence_count, 0))
        - (2 * coalesce(v_short_work_count, 0))
        - (2 * coalesce(v_excess_break_count, 0))
        - (4 * coalesce(v_unresolved_count, 0))
        + least(20, 0.5 * coalesce(v_safe_days, 0))
      ));
    end if;
  end if;

  -- ------------------------------------------------------------------
  -- manual_score and qc_score — weighted average of aspect ratings,
  -- normalised to a 0-100 scale
  -- ------------------------------------------------------------------
  with rated as (
    select
      ra.category,
      ra.weight,
      avg(er.score) / nullif(ra.max_score, 0) * 100.0 as aspect_pct
    from public.rating_aspects ra
    join public.employee_ratings er on er.aspect_id = ra.id
    where er.employee_id = p_employee_id
      and er.rating_period = p_period
      and ra.is_active
    group by ra.id, ra.category, ra.weight, ra.max_score
  )
  select
    sum(case when category = 'manual' then aspect_pct * weight end)
      / nullif(sum(case when category = 'manual' then weight end), 0),
    sum(case when category = 'qc' then aspect_pct * weight end)
      / nullif(sum(case when category = 'qc' then weight end), 0)
  into v_manual_score, v_qc_score
  from rated;

  -- ------------------------------------------------------------------
  -- weights with renormalisation when components are missing
  -- ------------------------------------------------------------------
  select coalesce(weight_attendance, 0.50),
         coalesce(weight_manual,     0.30),
         coalesce(weight_qc,         0.20)
    into v_w_att, v_w_man, v_w_qc
    from public.score_weight_config
   where period = p_period;

  if v_w_att is null then
    v_w_att := 0.50; v_w_man := 0.30; v_w_qc := 0.20;
  end if;

  -- Renormalise: zero-out weights for missing components, then divide.
  if v_attendance_score is null then v_w_att := 0; end if;
  if v_manual_score     is null then v_w_man := 0; end if;
  if v_qc_score         is null then v_w_qc  := 0; end if;
  v_w_sum := v_w_att + v_w_man + v_w_qc;

  if v_w_sum = 0 then
    v_total_score := null;
  else
    v_total_score := (
      coalesce(v_attendance_score, 0) * v_w_att
    + coalesce(v_manual_score,     0) * v_w_man
    + coalesce(v_qc_score,         0) * v_w_qc
    ) / v_w_sum;
  end if;

  -- ------------------------------------------------------------------
  -- map total → tier with caps
  -- ------------------------------------------------------------------
  v_tier := case
    when v_total_score is null then null
    when v_total_score >= 95 then 'SSS'
    when v_total_score >= 90 then 'SS'
    when v_total_score >= 85 then 'S'
    when v_total_score >= 75 then 'A'
    when v_total_score >= 65 then 'B'
    when v_total_score >= 55 then 'C'
    when v_total_score >= 40 then 'D'
    else 'F'
  end;

  v_capped := null;
  if v_tier in ('SSS', 'SS', 'S') then
    if v_is_new then
      v_tier := 'A';
      v_capped := 'new_employee';
    elsif v_is_parttime then
      v_tier := 'A';
      v_capped := 'parttime';
    end if;
  end if;

  -- ------------------------------------------------------------------
  -- upsert summary row
  -- ------------------------------------------------------------------
  insert into public.employee_score_summary as ess (
    employee_id, period, attendance_score, manual_score, qc_score,
    total_score, tier, tier_capped_reason, computed_at
  ) values (
    p_employee_id, p_period, v_attendance_score, v_manual_score, v_qc_score,
    v_total_score, v_tier, v_capped, now()
  )
  on conflict (employee_id, period) do update
    set attendance_score   = excluded.attendance_score,
        manual_score       = excluded.manual_score,
        qc_score           = excluded.qc_score,
        total_score        = excluded.total_score,
        tier               = excluded.tier,
        tier_capped_reason = excluded.tier_capped_reason,
        computed_at        = excluded.computed_at;

  -- Refresh ranks within outlet + global for this period.
  with ranked as (
    select employee_id,
           rank() over (
             partition by ess.period, e.home_outlet_id
             order by ess.total_score desc nulls last
           ) as r_outlet,
           rank() over (
             partition by ess.period
             order by ess.total_score desc nulls last
           ) as r_global
      from public.employee_score_summary ess
      join public.employees e on e.id = ess.employee_id
     where ess.period = p_period
  )
  update public.employee_score_summary ess
     set rank_outlet = ranked.r_outlet,
         rank_global = ranked.r_global
    from ranked
   where ess.employee_id = ranked.employee_id
     and ess.period      = p_period;

  select * into v_summary
    from public.employee_score_summary
   where employee_id = p_employee_id and period = p_period;

  return to_jsonb(v_summary);
end;
$$;

grant execute on function public.compute_employee_score(uuid, text)
  to authenticated;

-- ----------------------------------------------------------------------------
-- 8) Trigger — recompute on rating insert/update/delete
-- ----------------------------------------------------------------------------
create or replace function public.tg_recompute_after_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eid uuid;
  v_period text;
begin
  if tg_op = 'DELETE' then
    v_eid := old.employee_id;
    v_period := old.rating_period;
  else
    v_eid := new.employee_id;
    v_period := new.rating_period;
  end if;
  perform public.compute_employee_score(v_eid, v_period);
  return null;
end;
$$;

drop trigger if exists employee_ratings_recompute on public.employee_ratings;
create trigger employee_ratings_recompute
  after insert or update or delete on public.employee_ratings
  for each row execute function public.tg_recompute_after_rating();

-- ----------------------------------------------------------------------------
-- 9) employee_score_icons — VIEW: derive achievement/violation badges
-- ----------------------------------------------------------------------------
-- Icons are derived live (not stored) so they always reflect current data.
-- Each row: (employee_id, period, code, label, kind) where kind ∈ ('achievement','violation').
create or replace view public.employee_score_icons as
with this_period as (
  select to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM') as period
),
recap as (
  select * from public.get_site_leaderboard()
)
-- ⚡ Tepat Waktu — ≥ 20 safe_days, no late, no absence
select r.employee_id, tp.period,
       'punctual'    as code, '⚡ Tepat Waktu'    as label, 'achievement' as kind
  from recap r, this_period tp
 where r.safe_days >= 20 and r.late_count = 0 and r.absence_count = 0

union all
-- 🐌 Sering Terlambat — late_count ≥ 5
select r.employee_id, tp.period,
       'frequent_late' as code, '🐌 Sering Terlambat' as label, 'violation' as kind
  from recap r, this_period tp
 where r.late_count >= 5

union all
-- 🌙 Lupa Pulang — unresolved_count ≥ 3
select r.employee_id, tp.period,
       'forgot_clockout' as code, '🌙 Lupa Pulang' as label, 'violation' as kind
  from recap r, this_period tp
 where r.unresolved_count >= 3

union all
-- 📵 Sering Absen — absence_count ≥ 3
select r.employee_id, tp.period,
       'frequent_absent' as code, '📵 Sering Absen' as label, 'violation' as kind
  from recap r, this_period tp
 where r.absence_count >= 3

union all
-- 🏆 Top Outlet — rank_outlet = 1 in current period
select ess.employee_id, ess.period,
       'top_outlet' as code, '🏆 Top Outlet' as label, 'achievement' as kind
  from public.employee_score_summary ess, this_period tp
 where ess.period = tp.period and ess.rank_outlet = 1

union all
-- 🥇 Top Global — rank_global = 1 in current period
select ess.employee_id, ess.period,
       'top_global' as code, '🥇 Top Global' as label, 'achievement' as kind
  from public.employee_score_summary ess, this_period tp
 where ess.period = tp.period and ess.rank_global = 1

union all
-- 🔥 Streak Master — current_streak ≥ 30
select r.employee_id, tp.period,
       'streak_master' as code, '🔥 Streak 30+' as label, 'achievement' as kind
  from recap r, this_period tp
 where r.current_streak >= 30

union all
-- 💎 Konsisten — longest_streak ≥ 60
select r.employee_id, tp.period,
       'consistent' as code, '💎 Konsisten' as label, 'achievement' as kind
  from recap r, this_period tp
 where r.longest_streak >= 60;

grant select on public.employee_score_icons to authenticated;

-- ----------------------------------------------------------------------------
-- 10) get_employee_score_card — RPC for `/portal/admin/skor-tier/[id]` drawer
-- ----------------------------------------------------------------------------
-- Returns full score card: summary + icons + recent notes (top-level only;
-- replies fetched separately).
create or replace function public.get_employee_score_card(
  p_employee_id uuid,
  p_period text default to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM')
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := nullif(btrim(auth.jwt() -> 'app_metadata' ->> 'app_role'), '');
  v_can_access boolean;
  v_employee record;
  v_summary jsonb;
  v_icons jsonb;
  v_notes jsonb;
begin
  select id, name, position, home_outlet_id, employment_contract, created_at
    into v_employee
    from public.employees where id = p_employee_id;

  if not found then
    raise exception 'employee not found';
  end if;

  v_can_access :=
       v_role = 'admin'
    or public.score_caller_can_access_outlet(v_employee.home_outlet_id);

  if not v_can_access then
    raise exception 'access denied';
  end if;

  select to_jsonb(ess.*) into v_summary
    from public.employee_score_summary ess
   where ess.employee_id = p_employee_id and ess.period = p_period;

  select coalesce(jsonb_agg(jsonb_build_object(
           'code', code, 'label', label, 'kind', kind
         )), '[]'::jsonb)
    into v_icons
    from public.employee_score_icons
   where employee_id = p_employee_id and period = p_period;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', id,
           'parent_id', parent_id,
           'author_name', author_name,
           'author_role', author_role,
           'body', body,
           'created_at', created_at,
           'updated_at', updated_at
         ) order by created_at desc), '[]'::jsonb)
    into v_notes
    from public.employee_rating_notes
   where employee_id = p_employee_id and deleted_at is null;

  return jsonb_build_object(
    'employee', jsonb_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'position', v_employee.position,
      'home_outlet_id', v_employee.home_outlet_id,
      'employment_contract', v_employee.employment_contract,
      'created_at', v_employee.created_at,
      'is_new', v_employee.created_at >= (now() - interval '7 days')
    ),
    'summary', v_summary,
    'icons', v_icons,
    'notes', v_notes,
    'period', p_period
  );
end;
$$;

grant execute on function public.get_employee_score_card(uuid, text)
  to authenticated;

-- ----------------------------------------------------------------------------
-- 11) get_skor_tier_overview — RPC for `/portal/admin/skor-tier` main page
-- ----------------------------------------------------------------------------
-- Returns all employees grouped by tier for the given period, scoped to
-- caller's allowed outlets. Admin gets every employee; kepala/area get only
-- their managed outlets'.
create or replace function public.get_skor_tier_overview(
  p_period text default to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM'),
  p_outlet_id uuid default null
)
returns table (
  employee_id uuid,
  employee_name text,
  -- `position` is a SQL reserved word — quote it in the DDL so PG parses
  -- this as a column declaration rather than a `position(... in ...)`
  -- function call header.
  "position" text,
  home_outlet_id uuid,
  home_outlet_name text,
  photo_url text,
  employment_contract text,
  is_new boolean,
  tier text,
  tier_capped_reason text,
  total_score numeric,
  attendance_score numeric,
  manual_score numeric,
  qc_score numeric,
  rank_outlet int,
  rank_global int,
  icons jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    e.id                                              as employee_id,
    e.name                                            as employee_name,
    e.position                                        as "position",
    e.home_outlet_id                                  as home_outlet_id,
    o.name                                            as home_outlet_name,
    e.photo_url                                       as photo_url,
    e.employment_contract                             as employment_contract,
    (e.created_at >= (now() - interval '7 days'))     as is_new,
    coalesce(ess.tier, 'F')                           as tier,
    ess.tier_capped_reason                            as tier_capped_reason,
    ess.total_score                                   as total_score,
    ess.attendance_score                              as attendance_score,
    ess.manual_score                                  as manual_score,
    ess.qc_score                                      as qc_score,
    ess.rank_outlet                                   as rank_outlet,
    ess.rank_global                                   as rank_global,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', i.code, 'label', i.label, 'kind', i.kind
      ))
      from public.employee_score_icons i
      where i.employee_id = e.id and i.period = p_period
    ), '[]'::jsonb)                                   as icons
  from public.employees e
  left join public.outlets o on o.id = e.home_outlet_id
  left join public.employee_score_summary ess
    on ess.employee_id = e.id and ess.period = p_period
  where e.is_active is true
    and e.archived_at is null
    and (p_outlet_id is null or e.home_outlet_id = p_outlet_id)
    and (
      (auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin'
      or public.score_caller_can_access_outlet(e.home_outlet_id)
    );
$$;

grant execute on function public.get_skor_tier_overview(text, uuid)
  to authenticated;

-- ----------------------------------------------------------------------------
-- 12) Realtime publication
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'employee_score_summary'
  ) then
    alter publication supabase_realtime add table public.employee_score_summary;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'employee_rating_notes'
  ) then
    alter publication supabase_realtime add table public.employee_rating_notes;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 13) Seed default rating aspects (idempotent — uses ON CONFLICT)
-- ----------------------------------------------------------------------------
insert into public.rating_aspects (code, display_name, category, weight, max_score) values
  ('kebersihan',     'Kebersihan',          'manual', 1.0, 5),
  ('kecepatan',      'Kecepatan Kerja',     'manual', 1.0, 5),
  ('sikap',          'Sikap & Komunikasi',  'manual', 1.5, 5),
  ('inisiatif',      'Inisiatif',           'manual', 1.0, 5),
  ('qc_food_safety', 'QC Food Safety',      'qc',     2.0, 100),
  ('qc_layanan',     'QC Layanan Tamu',     'qc',     1.5, 100),
  ('qc_visual',      'QC Visual Outlet',    'qc',     1.0, 100)
  on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- 14) Backfill — compute scores for the current period for every active employee
-- ----------------------------------------------------------------------------
-- Done synchronously here so the first dashboard load is not empty. Cheap
-- because get_site_leaderboard is one query.
do $$
declare
  v_period text := to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM');
  v_eid uuid;
begin
  for v_eid in
    select id from public.employees where is_active is true and archived_at is null
  loop
    perform public.compute_employee_score(v_eid, v_period);
  end loop;
end $$;

-- Phase 54: Workforce Contract & Outlet Operating Mode
-- Additive migration: adds two enum types and two nullable-then-NOT-NULL columns.
-- Does NOT drop, rename, or destructively alter any existing data.
-- Safe to re-run (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS guards).
--
-- IMPORTANT: Review and apply manually in Supabase SQL Editor.
-- Requires explicit user approval before production execution.

-- ── 1. Create enum types ────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE public.employee_contract AS ENUM ('FULLTIME', 'PARTTIME');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.outlet_operating_mode AS ENUM ('NORMAL', 'TWENTY_FOUR_HOUR');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 2. Add columns with safe defaults ───────────────────────────────────────

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS employment_contract public.employee_contract
    DEFAULT 'FULLTIME'::public.employee_contract;

ALTER TABLE public.outlets
  ADD COLUMN IF NOT EXISTS operating_mode public.outlet_operating_mode
    DEFAULT 'NORMAL'::public.outlet_operating_mode;

-- ── 3. Backfill existing rows ───────────────────────────────────────────────
-- Ensures every pre-existing row has a non-null value before NOT NULL is applied.

UPDATE public.employees
  SET employment_contract = 'FULLTIME'::public.employee_contract
  WHERE employment_contract IS NULL;

UPDATE public.outlets
  SET operating_mode = 'NORMAL'::public.outlet_operating_mode
  WHERE operating_mode IS NULL;

-- ── 4. Tighten to NOT NULL ──────────────────────────────────────────────────
-- Safe because step 3 backfilled all nulls and DEFAULT handles future inserts.

ALTER TABLE public.employees
  ALTER COLUMN employment_contract SET NOT NULL;

ALTER TABLE public.outlets
  ALTER COLUMN operating_mode SET NOT NULL;

-- ── Done ────────────────────────────────────────────────────────────────────
-- After applying: existing employees default to FULLTIME, existing outlets to NORMAL.
-- The Flutter app already handles null gracefully via EmployeeContract.parse()
-- and OutletOperatingMode.parse(), so deployment order (APK vs SQL) does not matter.

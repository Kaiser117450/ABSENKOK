-- ============================================================
-- Phase 23: Employee Streaks Cache Table (GAME-01)
-- Additive migration — safe for production
-- ============================================================

CREATE TABLE IF NOT EXISTS employee_streaks (
  employee_id UUID PRIMARY KEY REFERENCES employees(id) ON DELETE CASCADE,
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_masuk_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE employee_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "streaks_select_admin" ON employee_streaks;
CREATE POLICY "streaks_select_admin" ON employee_streaks
  FOR SELECT
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin'
    OR (
      (auth.jwt() -> 'app_metadata' ->> 'app_role') = 'kepala_gerai'
      AND employee_id IN (
        SELECT id
        FROM employees
        WHERE home_outlet_id = (auth.jwt() -> 'app_metadata' ->> 'managed_outlet_id')::UUID
      )
    )
  );

DROP POLICY IF EXISTS "streaks_insert_service" ON employee_streaks;
CREATE POLICY "streaks_insert_service" ON employee_streaks
  FOR INSERT
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS "streaks_update_service" ON employee_streaks;
CREATE POLICY "streaks_update_service" ON employee_streaks
  FOR UPDATE
  USING (FALSE);

GRANT SELECT ON employee_streaks TO authenticated;

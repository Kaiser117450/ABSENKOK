-- Phase 46: Portal Employee Self-Read on employee_streaks
-- Additive migration — safe for production
--
-- Allows an authenticated portal employee to read their OWN streak row
-- by joining through employee_portal_accounts (same pattern as other
-- portal RLS policies in phase 37/39).

-- ── 1. Portal employee self-read policy ──────────────────────────────────────

DROP POLICY IF EXISTS "portal_employee_read_own_streak" ON employee_streaks;
CREATE POLICY "portal_employee_read_own_streak" ON employee_streaks
  FOR SELECT USING (
    employee_id IN (
      SELECT epa.employee_id
      FROM employee_portal_accounts epa
      INNER JOIN employees e ON e.id = epa.employee_id
      WHERE epa.auth_user_id = auth.uid()
        AND e.is_active = true
        AND e.archived_at IS NULL
    )
  );

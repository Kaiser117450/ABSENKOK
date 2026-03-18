-- ============================================================
-- Phase 23: Performance Indexes for Dashboard Queries
-- Additive — IF NOT EXISTS = safe to run multiple times
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_attendance_logs_outlet_scanned
  ON attendance_logs (scan_outlet_id, scanned_at);

CREATE INDEX IF NOT EXISTS idx_attendance_logs_employee_type
  ON attendance_logs (employee_id, type);

CREATE INDEX IF NOT EXISTS idx_employee_streaks_updated
  ON employee_streaks (updated_at);

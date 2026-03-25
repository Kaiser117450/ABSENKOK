# Phase 50: User Setup Required

**Generated:** 2026-03-25
**Phase:** 50-kiosk-device-boundary-hardening
**Status:** Incomplete

Complete these items for the kiosk boundary hardening to function in production. The repo changes are done; the live Supabase project still needs the additive SQL applied by a human.

## Environment Variables

None.

## Dashboard Configuration

- [ ] **Apply the Phase 50 kiosk boundary migration**
  - Location: Supabase Dashboard -> SQL Editor -> New Query
  - Set to: Run `sql/phase_50_kiosk_boundary_hardening_20260325.sql`
  - Notes: This migration is additive only. Review it first, then apply it with production approval because the live attendance system is already running.

## Verification

After completing setup, verify with:

```bash
# From the repo root, inspect the migration that must be applied
Select-String -Path sql/phase_50_kiosk_boundary_hardening_20260325.sql -Pattern "activate_kiosk_device|upsert_kiosk_heartbeat|set_device_nickname|archive_device"
```

Expected results:
- The SQL file contains the four hardened RPC definitions.
- Supabase SQL Editor has successfully applied the migration with no destructive changes.
- A kiosk can still activate through the existing outlet-name plus password screen after the migration is live.

---

**Once all items complete:** Mark status as "Complete" at top of file.

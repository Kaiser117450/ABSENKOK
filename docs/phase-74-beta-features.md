# Phase 74 — Beta features: Admin Password Reset + Read-only QC role

All three beta capabilities (attendance-photo grooming, **admin password reset**,
and the **read-only QC role**) ship behind a single build-time flag:
`ATTENDANCE_PHOTO_BETA`. A normal (non-beta) build hides them entirely.

```powershell
# Build the beta APK (release, signed, obfuscated)
powershell -ExecutionPolicy Bypass -File tool\build_beta.ps1

# Or a quick debug beta APK
powershell -ExecutionPolicy Bypass -File tool\build_beta.ps1 -Debug

# Equivalent raw command (must use the space-free C:\fl junction to the SDK):
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'; $env:TEMP='C:\tmp'; $env:TMP='C:\tmp'
C:\fl\bin\flutter.bat build apk --release --dart-define=ATTENDANCE_PHOTO_BETA=true --obfuscate --split-debug-info=build\debug-info
```

The flag is read in `lib/core/constants.dart`:
`AppConstants.attendancePhotoBetaEnabled` (raw) and its semantic alias
`AppConstants.betaFeaturesEnabled` (used by the Phase-74 gates).

---

## 1. Admin password reset ("lupa password")

A full **admin** can reset any other privileged account's password when a user
forgets theirs. The system generates a temporary password (shown once) and
forces the user to change it on next login.

- **UI**: Admin → **Gerai** tab → "Reset Password Akun" (beta-gated).
  Lists all privileged accounts (admin / kepala gerai / area supervisor / QC),
  searchable. Tap a user → confirm → temp password dialog with Copy / Share.
- **Cannot reset self** (admins use the normal change-password flow) — enforced
  server-side.
- **Backend**: Edge Function `reset-user-password` (service_role,
  `verify_jwt=true`). Verifies caller is `admin`, generates a 12-char password,
  calls `auth.admin.updateUserById` with `must_change_password=true`.
- **Listing**: RPC `admin_list_app_users()` (SECURITY DEFINER, admin-only).
- **Flutter**: `lib/services/admin_user_service.dart`,
  `lib/screens/admin/admin_reset_password_screen.dart`.

On next login the existing first-login flow (`/admin/change-password` +
`clear-must-change-password`) takes over automatically.

## 2. Read-only QC role

A new `app_role = 'qc'` — an outlet-scoped, **read-only** grooming reviewer.

- QC logs in via the normal admin login. It lands on a standalone grooming
  screen at `/qc/grooming` (outside the admin shell) titled "Grooming QC
  (Lihat)" with its own logout button.
- QC can browse grooming results, photos, AI verdicts and analytics for its
  assigned outlet(s) only, **but cannot change anything**: no AI override
  button, no AI-rules editor, no other admin pages.
- Scope: assigned to one or more outlets (`managed_outlet_id` /
  `managed_outlet_ids`), like the other scoped roles. The grooming filter only
  shows outlets the QC can access.
- **Create a QC account**: Admin → **Buat Akun** → role "QC" (beta-gated),
  pick the outlet(s). Password is generated; user must change on first login.
- **Backend RLS**: `attendance_photo_analysis_qc_select` lets a QC SELECT only
  analysis rows for its outlet(s), via the `qc_can_access_outlet(uuid)` helper
  (strictly the `qc` role — never leaks access to other roles/tables). The
  admin-only `apply_grooming_qc_override` RPC already rejects non-admins, so QC
  writes are impossible at every layer.
- **Note**: the AI-override affordance is now hidden for *all* non-admin roles
  (QC, kepala gerai, area supervisor), fixing a latent case where a scoped
  admin could tap "Koreksi AI" and hit the admin-only RPC.

SQL: `sql/phase_74_qc_role_and_password_reset.sql` (applied as migration
`phase_74_qc_role_and_password_reset`).

## 3. Front UI polish

Subtle, additive micro-interactions on the kiosk idle + scan screens
(`lib/screens/kiosk/kiosk_idle_screen.dart`,
`lib/screens/kiosk/kiosk_scan_screen.dart`) — NFC-ready status-dot glow pulse,
NFC ring tap haptic + scale, header logo press feedback, snappier sync
indicator, and a success spring settle. No layout changes, no new packages.

---

## Manual QA checklist (on the beta APK)

- [ ] Admin → Gerai → Reset Password Akun: list loads; reset a kepala-gerai →
      temp password shown; that user must change password on next login.
- [ ] Admin cannot reset own account (icon shows "self").
- [ ] Create a QC account for one outlet; share credentials.
- [ ] Log in as QC → lands on grooming (read-only); only its outlet's data is
      visible; no "Koreksi AI"/"Aturan AI"; logout works.
- [ ] Kepala gerai grooming view also has no "Koreksi AI" button.
- [ ] Admin grooming still has full override + rules editor.
- [ ] Kiosk idle/scan animations feel alive; no jank; NFC still scans.

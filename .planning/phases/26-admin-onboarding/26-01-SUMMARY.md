---
plan: 26-01
phase: 26-admin-onboarding
status: complete
completed_at: 2026-03-19
---

# Plan 26-01 Summary: Secure Admin Onboarding Pipeline

## What was built

- **`supabase/functions/create-admin-user/index.ts`** — Deno Edge Function that creates Kepala Gerai accounts server-side using the service_role key. Verifies caller is admin via JWT, generates a 12-char secure password via `crypto.getRandomValues()`, sets `app_metadata.app_role = 'kepala_gerai'` and `managed_outlet_id`, returns credentials in response.

- **`lib/services/admin_onboarding_service.dart`** — Flutter service that invokes the Edge Function. Includes `createUser()` (returns typed `CreateUserResult`) and `getOutlets()`. No service_role key in Flutter code.

- **`lib/screens/admin/create_admin_screen.dart`** — Full 3-state screen (form → loading → success) with:
  - Form: name, email, outlet dropdown with validation
  - Loading: centered spinner + "Membuat akun..." text
  - Success: animated banner, credential card with password toggle, WhatsApp share, PDF audit trail, copy to clipboard, "Buat Akun Lagi" reset

- **`lib/app.dart`** — Added import, GoRoute at `/admin/create-account` inside ShellRoute, and kepala_gerai redirect guard blocking the route.

- **`pubspec.yaml`** — Added `url_launcher: ^6.3.1`

- **`android/app/src/main/AndroidManifest.xml`** — Added WhatsApp package queries for Android 11+

## Plans 02 and 03 merged into 01

Since Plans 02 (WhatsApp sharing) and 03 (PDF audit trail) both modify only `create_admin_screen.dart`, all three were implemented together to avoid merge conflicts and reduce build iterations.

## User action required

Deploy Edge Function to Supabase:
```bash
npx supabase link --project-ref tmapxdftdhxovthgbhww
npx supabase functions deploy create-admin-user --no-verify-jwt
```

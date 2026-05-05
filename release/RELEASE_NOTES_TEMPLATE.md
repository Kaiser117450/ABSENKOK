# ABSENKOK — Release

This release bundles the kiosk APK plus the additive Supabase migrations and
documentation that go with it.

## Artifacts

| File | What it is |
| --- | --- |
| `app-arm64-v8a-release-*.apk` | Production APK for 64-bit ARM kiosks (most modern Android tablets). Use this. |
| `app-armeabi-v7a-release-*.apk` | 32-bit ARM fallback. Only for very old hardware. |
| `app-x86_64-release-*.apk` | x86_64 build (emulators / x86 tablets). |
| `app-release-*.apk` | Universal APK (all ABIs in one file, larger). Use only if you don't know which ABI your device is. |
| `kiosk.env.example` | Template documenting `SUPABASE_URL` + `SUPABASE_ANON_KEY` for self-hosters who fork the repo. The actual values used to build this release are baked into the APK; this file is **not** required to install. |

## Database migration — apply BEFORE distributing the APK

Open the Supabase SQL Editor and run, in order:

1. `sql/phase_70_auth_rate_limit.sql`
2. `sql/phase_71_employee_scoring.sql`

Both files are idempotent (`create … if not exists`, `revoke … grant …`,
`replace into` patterns) so re-running them is safe.

### Backwards compatibility with older kiosk APKs

These migrations are **strictly additive** — no existing column, table, RPC,
or RLS policy is dropped, renamed, or made stricter. Concretely:

- **`phase_70_auth_rate_limit.sql`** affects only the web portal at
  `/portal/auth/*`. The kiosk APK never calls these endpoints, so the
  migration is invisible to it.
- **`phase_71_employee_scoring.sql`** adds new tables (`rating_aspects`,
  `employee_ratings`, `employee_score_summary`, `employee_rating_notes`,
  `score_weight_config`) and a `compute_employee_score` RPC. Older kiosk
  APKs do not query any of these, so they are never accessed.
- **`move_employee_to_outlet` RPC** (introduced in PR #25) is *additive*:
  the kiosk APK in this release calls the RPC, while older APK versions
  still issue the equivalent `UPDATE employees SET home_outlet_id = …`
  directly. Both paths are allowed. A future migration can lock the direct
  UPDATE path down once every kiosk has been upgraded.

You can therefore apply the migration first and roll out the new APK across
your kiosk fleet at your own pace; old and new APKs coexist on the same
database without breakage.

## Vercel environment variables (web portal)

Set these in the Vercel project before redeploying the web portal:

| Variable | Required | Notes |
| --- | --- | --- |
| `PORTAL_SECRET` | yes | ≥16 char random string, server-side only. Used to derive the deterministic passwordless password. |
| `PUBLIC_SUPABASE_URL` | yes | Same as kiosk `SUPABASE_URL`. |
| `PUBLIC_SUPABASE_ANON_KEY` | yes | Same as kiosk `SUPABASE_ANON_KEY`. |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | Server-side only. NEVER ship to client. |
| `PUBLIC_TURNSTILE_SITE_KEY` | yes | Cloudflare Turnstile site key (public). |
| `TURNSTILE_SECRET_KEY` | yes | Cloudflare Turnstile secret (server-side only). |

## Installation (kiosk)

1. Settings → Security → enable “Install from unknown sources” for the file
   manager you'll use.
2. Copy the `app-arm64-v8a-release-*.apk` to the device (USB / network).
3. Tap to install. Android prompts for confirmation; the existing kiosk
   data is preserved because the APK is signed with the same upload key as
   prior releases.
4. Launch ABSENKOK. The kiosk reads `SUPABASE_URL` + `SUPABASE_ANON_KEY`
   from its bundled `.env` asset and connects automatically.

## Rollback

If a serious regression surfaces:

1. Reinstall the previous APK (the database accepts both versions concurrently).
2. The migrations themselves do not need to be rolled back — they are additive.
   Newly added tables remain unused by the older APK.

If you absolutely need to drop the new objects (not recommended), run:

```sql
-- phase_71 rollback (additive only, drops new tables)
drop trigger if exists trg_refresh_employee_score on public.employee_ratings;
drop function if exists public.compute_employee_score(uuid, date) cascade;
drop function if exists public.refresh_employee_score_summary() cascade;
drop table if exists public.employee_score_summary cascade;
drop table if exists public.employee_rating_notes cascade;
drop table if exists public.employee_ratings cascade;
drop table if exists public.rating_aspects cascade;
drop table if exists public.score_weight_config cascade;

-- phase_70 rollback
drop function if exists public.check_and_increment_rate_limit(text, text, int, int) cascade;
drop table if exists public.auth_rate_limit_state cascade;
```

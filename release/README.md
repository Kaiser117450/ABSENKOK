# Release pipeline

This directory holds the pieces that the `Android Release Build` GitHub Actions
workflow references — release notes template, kiosk env example, and the
consolidated migration bundle.

## One-time setup — GitHub Actions secrets

The release workflow (`.github/workflows/android-release.yml`) cannot build a
signed APK without these. Add them under
**GitHub → Settings → Secrets and variables → Actions → Repository secrets**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w 0 < /path/to/upload-keystore.jks` (Linux/macOS) or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))` (PowerShell). Must be the same upload keystore that signed the previous release — Android refuses in-place upgrades across keystores. |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` value from your local `android/key.properties`. |
| `ANDROID_KEY_PASSWORD` | `keyPassword` value from `android/key.properties`. |
| `ANDROID_KEY_ALIAS` | `keyAlias` value from `android/key.properties`. |
| `KIOSK_SUPABASE_URL` | `https://<project-ref>.supabase.co` for the production Supabase project. |
| `KIOSK_SUPABASE_ANON_KEY` | Production anon key from Supabase → Settings → API. |

These values never appear in the repo. The workflow reconstructs the keystore
and `.env` only inside the ephemeral runner.

## Producing a release

1. Apply `release/migrations.sql` via the Supabase SQL Editor (idempotent).
2. Bump `version:` in `pubspec.yaml` if needed (the workflow reads it for
   `--build-name`/`--build-number`).
3. Tag and push:

   ```
   git tag v8.8.0+8800
   git push origin v8.8.0+8800
   ```

4. The Actions workflow builds split-per-ABI + universal APKs, then opens a
   **draft** release with the artifacts attached. Review and publish from the
   GitHub UI.

To smoke-test the workflow without cutting a release, run it manually from the
Actions tab — the APK is uploaded as a workflow artifact (no GitHub Release).

## Files

- `migrations.sql` — concatenation of `sql/phase_70_auth_rate_limit.sql` and
  `sql/phase_71_employee_scoring.sql`, wrapped in a single transaction.
- `kiosk.env.example` — template for the `.env` asset bundled into the kiosk APK.
- `RELEASE_NOTES_TEMPLATE.md` — body used for tagged GitHub Releases. Contains
  the migration apply order, backwards-compatibility statement, install
  instructions, and rollback SQL.

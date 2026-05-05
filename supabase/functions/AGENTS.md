# AGENTS.md — supabase/functions/

<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-05 | Updated: 2026-04-05 -->

## Purpose

Supabase Edge Functions — Deno runtime serverless functions for privileged backend operations.

## Subdirectories

| Directory | Role |
|-----------|------|
| `clear-must-change-password/` | Clears the password-change flag after an employee's first login |
| `create-admin-user/` | Provisions scoped admin auth users with `app_role: kepala_gerai` or `area_supervisor` metadata |
| `provision-employee-portal-user/` | Creates employee portal credentials (email/password from employee data) |

## For AI Agents

- Edge Functions run on **Deno** — use Deno-compatible imports (e.g., `jsr:@supabase/supabase-js`).
- Each function has its own `index.ts` entrypoint.
- Use the **Supabase service role key** for privileged operations (creating users, updating metadata).
- Always validate request input and return proper HTTP status codes.
- Deploy with: `supabase functions deploy <function-name>`.
- Test locally with: `supabase functions serve`.
- JWT verification is enabled by default — disable only for webhooks or public endpoints.

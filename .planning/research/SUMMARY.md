# Project Research Summary

**Project:** Absensi Enakko
**Domain:** Employee portal attendance recap
**Researched:** 2026-03-23
**Confidence:** HIGH

## Executive Summary

`v6.3` should stay inside the existing employee portal and remain read-only. The safest path is to extend the shipped Astro SSR portal with one attendance recap surface backed by an authenticated recap contract, rather than broadening into requests, approvals, or a second frontend stack.

The main risks are consistency and scope. The recap must match the product's existing logical-day rules for overnight work, and it must explain exception days clearly enough that employees can trust what they see. That pushes the milestone toward three phases: recap data contract first, portal recap UX second, and cross-repo hardening/verification third.

## Key Findings

### Recommended Stack

No new framework is justified for this milestone. The current `astro@5.18.1` + `@astrojs/vercel@9.0.5` website, the shipped portal auth flow built on `@supabase/ssr@0.9.0` + `@supabase/supabase-js@2.99.3`, and additive Supabase RPCs are the right baseline.

**Core technologies:**
- Astro SSR routes: extend the existing protected portal
- Supabase SSR/authenticated RPCs: keep employee recap reads server-side and scoped
- Existing portal components/state model: preserve the phone-first UX already shipped

### Expected Features

The milestone should solve one job: employees can review their recent attendance confidently without asking admin.

**Must have (table stakes):**
- Month-to-date summary counts
- Recent day-by-day attendance history
- Clear exception visibility for sakit, izin, libur, and incomplete days
- Mobile-first recap inside the current portal shell

**Should have (competitive):**
- Schedule context beside attendance days
- Attention markers that make problematic days obvious

**Defer (v6.4+):**
- Attendance correction requests
- Manager/admin approvals
- Shift reminders or notifications

### Architecture Approach

Keep employee identity resolution in the current server-side portal helpers, add a recap-specific authenticated RPC or loader contract, and render the result through typed portal page states. The portal page should receive recap meaning, not raw attendance log rows that force the UI to guess.

**Major components:**
1. Portal recap loader — resolves employee identity and fetches recap data
2. Recap contract — merges attendance logs with schedule context and logical-day rules
3. Portal recap components — summary cards plus daily history cards for phone-sized screens

### Critical Pitfalls

1. **Logical-day drift** — keep recap dates aligned with `Asia/Makassar` and existing overnight rules
2. **Employee scope leakage** — keep recap reads behind authenticated employee-scoped RPCs
3. **Exception ambiguity** — define and render exception states explicitly
4. **Scope creep into request workflows** — keep v6.3 read-only
5. **Cross-repo planning drift** — keep SQL, website, and planning artifacts synchronized

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 42: Attendance Recap Read Model
**Rationale:** Portal recap trust depends on correct employee scope and logical-day semantics before any UI work.
**Delivers:** Authenticated recap query contract, exception definitions, and any supporting indexes.
**Addresses:** `ATTN-02`, `ATTN-03`
**Avoids:** logical-day drift and query-scope leaks

### Phase 43: Portal Attendance Recap Surface
**Rationale:** Once the data contract is trustworthy, the employee-facing recap can stay focused and mobile-first.
**Delivers:** recap section/page, month summary cards, recent history list, and explicit exception presentation.
**Uses:** existing portal shell and state patterns
**Implements:** `ATTN-01`, `ATTN-04`, `ATTN-05`, `PORT-03`, `PORT-04`

### Phase 44: Portal Recap Hardening
**Rationale:** Portal work spans SQL and the separate website repo, so a closeout/hardening slice is needed to keep artifacts and shipped behavior aligned.
**Delivers:** verification pass, copy/polish fixes, and planning artifact synchronization.
**Uses:** the shipped recap path from phases 42-43
**Implements:** cross-repo release readiness and documentation discipline

### Phase Ordering Rationale

- Data and semantics come first because employees will distrust recap immediately if dates or exception states are wrong.
- UI comes second because it should consume one stable recap contract.
- Hardening closes the cross-repo drift that was accepted in the last two milestone archives.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 42:** exact SQL shape for summary counts and exception detection

Phases with standard patterns (skip research-phase):
- **Phase 43:** portal card/list rendering inside the existing shell
- **Phase 44:** verification and planning synchronization

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against the current website repo and official Astro/Supabase docs |
| Features | HIGH | Driven by the chosen milestone scope and existing portal backlog |
| Architecture | HIGH | Extending the current portal is clearly lower-risk than adding a new surface |
| Pitfalls | HIGH | Risks are already visible in prior portal and milestone-closeout work |

**Overall confidence:** HIGH

### Gaps to Address

- Exact summary metrics should stay count-based and not drift into payroll logic
- The recap read model should be tested against at least one overnight-shift example before shipping

## Sources

### Primary (HIGH confidence)
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\package.json`
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\src\lib\portal\employee.ts`
- Local repo: `C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter\sql\phase_39_portal_read_path_hardening_20260323.sql`
- https://docs.astro.build/en/guides/on-demand-rendering/
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/guides/database/postgres/row-level-security

### Secondary (MEDIUM confidence)
- https://help.sap.com/doc/8cd7b02f4e9c4a569bab136a7caa116e/2405/en-US/SAP%20SuccessFactors%20Time%20Tracking%201H%202024.pdf

---
*Research completed: 2026-03-23*
*Ready for roadmap: yes*

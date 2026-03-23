# Pitfalls Research

**Domain:** Employee portal attendance recap
**Researched:** 2026-03-23
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Logical-day drift from kiosk/admin rules

**What goes wrong:**
The portal recap attributes attendance to the wrong day for overnight or cross-midnight shifts.

**Why it happens:**
Developers treat raw timestamps as calendar days instead of reusing the product's logical-day rules.

**How to avoid:**
Anchor recap dates to `Asia/Makassar`, use one recap contract for both summary and day history, and carry forward the existing overnight handling rules explicitly.

**Warning signs:**
Employees complain that a late-night shift shows up on the next day, or portal totals do not match admin reports.

**Phase to address:**
Phase 42

---

### Pitfall 2: Employee data leakage through admin-shaped queries

**What goes wrong:**
Portal pages accidentally read attendance data with broader scope than the authenticated employee should see.

**Why it happens:**
The shortest path is often to reuse existing admin/service-role query patterns from internal tooling.

**How to avoid:**
Keep recap reads behind authenticated RPCs, resolve employee identity server-side, and fail closed when mapping is missing.

**Warning signs:**
Browser code needs direct table access, or recap pages receive employee IDs from the client.

**Phase to address:**
Phase 42

---

### Pitfall 3: Confusing exception states

**What goes wrong:**
Employees cannot tell whether a day was libur, sakit, izin, missing clock-out, or simply has no qualifying attendance record.

**Why it happens:**
The UI compresses too many states into one generic "masalah" badge.

**How to avoid:**
Define exception categories in the recap model before building the UI and render them with distinct copy and styling.

**Warning signs:**
Support questions start with "Kenapa ini merah?" instead of the portal itself explaining the reason.

**Phase to address:**
Phase 43

---

### Pitfall 4: Turning a read-only recap milestone into a workflow milestone

**What goes wrong:**
The milestone grows to include correction requests, manager approvals, or notifications before recap is stable.

**Why it happens:**
Recap naturally exposes issues, so it is tempting to add the write path immediately.

**How to avoid:**
Treat v6.3 as visibility only. Capture exceptions clearly now, then plan employee requests as the next milestone.

**Warning signs:**
Requirements start mentioning forms, mutation endpoints, or admin approval queues.

**Phase to address:**
Phase 43

---

### Pitfall 5: Cross-repo execution drift

**What goes wrong:**
Planning, SQL, and website implementation stop matching after the first portal hardening pass.

**Why it happens:**
Portal work spans the Flutter planning repo and the separate Astro website repo, so quick fixes bypass documentation.

**How to avoid:**
Keep the recap read model, portal helpers, and planning traceability in sync from the start of the milestone.

**Warning signs:**
Shipped code references new RPCs or page states that never appear in planning artifacts.

**Phase to address:**
Phase 44

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Build recap from multiple ad hoc page queries | Faster first render | Hard-to-debug drift between summary and daily history | Never for this milestone |
| Skip explicit exception labels | Less UI copy work | Employees still need admin help to interpret recap | Never |
| Leave planning artifacts behind the shipped website path | Faster closeout | Repeats the v6.1/v6.2 documentation drift | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Astro SSR + Supabase auth | Trusting a stale session object client-side | Verify the user on the server and resolve employee identity before loading recap data. |
| Attendance recap + schedules | Joining raw logs without business-local day rules | Normalize recap dates with the same timezone and logical-day contract used elsewhere. |
| Portal UI + planning docs | Treating website changes as "small enough" to skip planning updates | Keep roadmap and requirements aligned with the actual RPC/page changes. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded attendance history windows | Slow recap loads as logs grow | Limit v6.3 to current month plus recent history and index by employee/date | Noticeable once logs grow well beyond the current staff footprint |
| Duplicate summary calculations in UI | Counts disagree across cards and lists | Derive summary and history from one trusted recap dataset | As soon as exception rules evolve |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Passing employee IDs from the browser into recap reads | Horizontal data access | Resolve employee identity entirely server-side. |
| Granting broad table access to portal roles | Exposure of internal HR data | Keep portal reads behind authenticated functions with narrow grants. |
| Reusing admin-only endpoints for employees | Scope bypass and maintenance drift | Create employee-scoped recap contracts explicitly. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing raw event jargon only | Employees do not know what action to take | Pair timestamps with clear daily status labels and short explanation text. |
| Hiding exceptions deep in the list | Problems are missed | Surface attention states and counts prominently near the top. |
| Desktop-shaped tables in the portal | Poor phone usability | Reuse the card/list layout already proven in the portal schedule view. |

## "Looks Done But Isn't" Checklist

- [ ] **Attendance recap:** Summary counts and day history come from the same trusted dataset.
- [ ] **Overnight handling:** Cross-day scans match the existing logical-day rule in portal output.
- [ ] **Exception states:** Missing clock-out, sakit, izin, libur, and empty history each have distinct behavior.
- [ ] **Cross-repo artifact sync:** Planning docs, SQL migration, and website loader/component names match shipped code.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Logical-day drift | HIGH | Correct the recap contract centrally, backfill tests, and verify against known overnight examples. |
| Query scope leak | HIGH | Revoke the broken path immediately, replace it with a narrowed RPC, and re-verify grants. |
| Cross-repo drift | MEDIUM | Update planning artifacts before milestone closeout and document the actual shipped RPC/page surface. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Logical-day drift | Phase 42 | Recap output matches known overnight attendance cases. |
| Query scope leak | Phase 42 | Employee recap loads without client-supplied employee identifiers. |
| Confusing exception states | Phase 43 | Each exception day renders with distinct copy and styling. |
| Workflow scope creep | Phase 43 | Requirements remain read-only and exclude requests/approvals. |
| Cross-repo drift | Phase 44 | Planning artifacts match the shipped SQL and website implementation. |

## Sources

- Local repo: existing portal code and SQL functions from phases 37-39
- `.planning/PROJECT.md` and `.planning/STATE.md` known debt notes for v6.1/v6.2
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/reference/javascript/auth-getuser

---
*Pitfalls research for: employee portal attendance recap*
*Researched: 2026-03-23*

# Milestone v7.0 Requirements

**Defined:** 2026-03-23
**Core Value:** Reliable, 24/7 unattended NFC attendance with accurate cross-day shift handling and real-time admin visibility.

## 1. Build Baseline

- [x] **BUILD-01**: Operator can run the canonical Android release command from a clean checkout and reach release packaging without the current Dart compile failures.
- [x] **BUILD-02**: Operator can run one preflight release check that fails before signing when analysis, tests, or release-only compile steps are broken.
- [x] **BUILD-03**: Operator can identify the active milestone version from `pubspec.yaml` and generated release artifact names without cross-checking planning docs manually.

## 2. Toolchain Contract

- [x] **TOOL-01**: Operator can build with an explicitly documented Java runtime for Gradle instead of relying on whichever `java` is first on PATH.
- [x] **TOOL-02**: Operator can follow a pinned Flutter/Kotlin/Gradle compatibility decision for v7.0 without using ad hoc bypass flags or surprise upgrades.

## 3. Signing & Artifacts

- [x] **REL-01**: Operator can produce a release artifact signed with the private upload keystore instead of the debug keystore.
- [ ] **REL-02**: Operator can produce the agreed release artifact set from one validated release lane: canonical `.aab`, plus release `.apk` only if outlet side-loading still requires it.
- [ ] **REL-03**: Operator can retain the matching split debug info or symbol artifacts for each signed release and verify the shrunken release build before distribution.

## 4. Release Operations

- [ ] **OPS-01**: A second operator can reproduce the expected release artifact set from the documented local runbook without guessing secret/bootstrap prerequisites.

## Future Requirements Carried Forward

### Product Work

- **ATTN-06**: Employee can filter attendance recap by custom date range or prior month.
- **ATTN-07**: Employee can submit an attendance correction or dispute request from an exception day.
- **REQ-01**: Employee can submit time-off or absence requests through the portal.
- **REQ-02**: Manager/admin can approve or reject employee requests with an auditable status change.
- **NOTF-01**: Employee receives reminders or status notifications for upcoming work or request changes.
- **GRID-D1**: Schedule grid tap-to-cycle shift assignment.
- **GRID-D2**: Schedule grid copy-week feature.
- **GRID-D3**: Schedule grid today-column highlight.
- **LATE-01**: Keterlambatan automatic flagging vs shift start time.

### Release Follow-Ups

- **AUTO-01**: Release automation can publish artifacts or GitHub releases after the local release lane is proven.
- **PERF-01**: Build-speed optimization can reduce turnaround time without weakening release guarantees.
- **SIZE-01**: APK/AAB size and runtime startup can be tuned after the signed release baseline is stable.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Employee portal mutation flows in v7.0 | Product scope stays frozen until release reliability is restored. |
| CI/CD cloud automation in v7.0 | Local deterministic release lane must exist before automation. |
| Kotlin 2.x migration in v7.0 | `nfc_manager` compatibility is still a known constraint and should be handled as a separate spike. |
| Website/Astro deployment work | This milestone is scoped to the Flutter Android release path only. |
| iOS release packaging | Product remains Android-only. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 46 | Complete |
| BUILD-03 | Phase 46 | Complete |
| BUILD-02 | Phase 47 | Complete |
| TOOL-01 | Phase 47 | Complete |
| TOOL-02 | Phase 47 | Complete |
| REL-01 | Phase 48 | Complete |
| REL-02 | Phase 48 | Pending |
| REL-03 | Phase 48 | Pending |
| OPS-01 | Phase 49 | Pending |

**Coverage:**
- v7.0 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-03-23*
*Last updated: 2026-03-23 after completing Phase 47 Toolchain Contract & Preflight Gates*

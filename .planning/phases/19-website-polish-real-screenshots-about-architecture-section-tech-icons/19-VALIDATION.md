---
phase: 19
slug: website-polish-real-screenshots-about-architecture-section-tech-icons
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro build verification (no test runner — static site) |
| **Config file** | astro.config.mjs |
| **Quick run command** | `npx astro build` |
| **Full suite command** | `npx astro build && Select-String -Path dist/index.html -Pattern "enakko" -Quiet` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx astro build`
- **After every plan wave:** Run full build + content verification
- **Before `/gsd-verify-work`:** Full build must be clean
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | WEB-P01 | build | `npx astro build` | ✅ | ⬜ pending |
| 19-01-02 | 01 | 1 | WEB-P02 | build+grep | `npx astro build && grep "pilih" dist/index.html` | ✅ | ⬜ pending |
| 19-02-01 | 02 | 1 | WEB-P03 | build+grep | `npx astro build && grep "Architecture" dist/index.html` | ✅ | ⬜ pending |
| 19-02-02 | 02 | 1 | WEB-P04 | build+grep | `npx astro build && grep "Flutter" dist/index.html` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — Astro build is the test.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hero shows real photo | WEB-P01 | Visual check | Open localhost:4321, verify hero has phone photo not CSS mockup |
| Screenshots match sections | WEB-P02 | Visual check | Verify screenshot images appear in Features/HowItWorks |
| About section looks good | WEB-P03 | Visual check | Scroll to About section, verify layout and content |
| SVG icons render | WEB-P04 | Visual check | Check Flutter/Supabase SVG icons visible in About section |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

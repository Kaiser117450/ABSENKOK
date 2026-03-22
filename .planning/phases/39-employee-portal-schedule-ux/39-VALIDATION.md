---
phase: 39
slug: employee-portal-schedule-ux
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-22
---

# Phase 39 - Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Astro `astro check` + `astro build`; targeted PowerShell source-contract checks |
| Config file | `C:\\Users\\HYPE R Series\\Desktop\\projekan\\absenkok-website\\package.json` |
| Quick run command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| Full suite command | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |
| Estimated runtime | ~20 seconds |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Automated Command |
|---------|------|------|-------------|-------------------|
| 39-01-01 | 01 | 1 | LINK-02 | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run check"` |
| 39-01-02 | 01 | 1 | PORT-02 | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/lib/portal/home.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/components/portal/PortalStatePanel.astro' -Pattern 'loading','empty','not-linked','error' | Measure-Object"` |
| 39-02-01 | 02 | 2 | AUTH-04 | `powershell -Command "Select-String -Path 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/auth/sign-out.ts','C:/Users/HYPE R Series/Desktop/projekan/absenkok-website/src/pages/portal/login.astro' -Pattern \"scope: 'local'\",'signed_out=1' | Measure-Object"` |
| 39-02-02 | 02 | 2 | PORT-01 | `powershell -Command "Set-Location 'C:/Users/HYPE R Series/Desktop/projekan/absenkok-website'; npm run build"` |

## Manual Verifications

- Phone-width browser view stays one-column and readable.
- Unlinked employee account sees no schedule data.
- Portal logout ends only the current portal session.

## Validation Sign-Off

- [ ] All tasks have automated verification
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

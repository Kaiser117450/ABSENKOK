---
phase: 18
slug: absenkok-landing-website
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-12
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Astro built-in check + build validation |
| **Config file** | `astro.config.mjs` |
| **Quick run command** | `npx astro check` |
| **Full suite command** | `npx astro check && npx astro build` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx astro check`
- **After every plan wave:** Run `npx astro check && npx astro build`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | WEB-01 | smoke | `npx astro build && findstr /i "hero" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-02 | 01 | 1 | WEB-02 | smoke | `npx astro build && findstr /i "fitur" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-03 | 01 | 1 | WEB-03 | smoke | `npx astro build && findstr /i "cara-kerja" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-04 | 01 | 1 | WEB-04 | smoke | `npx astro build && findstr /i "github.com" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-05 | 01 | 1 | WEB-05 | smoke | `npx astro build && findstr /i "Akmal" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-06 | 01 | 1 | WEB-06 | manual | Chrome DevTools responsive test | N/A | ⬜ pending |
| 18-01-07 | 01 | 1 | WEB-07 | smoke | `npx astro build && findstr /i "lang=\"id\"" dist\index.html` | ❌ W0 | ⬜ pending |
| 18-01-08 | 01 | 1 | WEB-08 | smoke | `npx astro build && dir dist\_astro\*.js` (should be empty) | ❌ W0 | ⬜ pending |
| 18-01-09 | 01 | 1 | WEB-09 | smoke | `npx astro build && Test-Path dist\sitemap-index.xml` | ❌ W0 | ⬜ pending |
| 18-01-10 | 01 | 1 | WEB-10 | manual | Vercel deployment verification | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `npm create astro` — scaffold project at `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\`
- [ ] `npm install` — all dependencies (astro, tailwindcss, @astrojs/vercel, @astrojs/sitemap, sharp, @fontsource/inter)
- [ ] `astro.config.mjs` — Astro 5 config with Tailwind, Vercel, Sitemap integrations
- [ ] `src/styles/global.css` — Tailwind v4 CSS-first config with brand colors
- [ ] `tsconfig.json` — TypeScript config

*(This is a greenfield project — ALL infrastructure is Wave 0)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Responsive layout | WEB-06 | Visual layout testing | Open in Chrome DevTools, test 375px/768px/1440px viewports |
| Vercel deploy | WEB-10 | Requires Vercel account | `vercel deploy --prod` and verify live URL |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

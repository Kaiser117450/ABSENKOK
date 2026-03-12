---
phase: 19-website-polish-real-screenshots-about-architecture-section-tech-icons
plan: 01
subsystem: ui
tags: [astro, image-optimization, webp, screenshots, hero-section]

# Dependency graph
requires:
  - phase: 18-absenkok-landing-website
    provides: "Astro 5 website with Hero and HowItWorks components"
provides:
  - "5 optimized app screenshots in src/assets/images/ (kebab-case)"
  - "Hero section with real <Image> screenshot replacing CSS mockup"
  - "HowItWorks section with companion screenshots per step"
  - "team-hands.png image ready for About section (Plan 02)"
affects: [19-02]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Astro <Image> component for automatic WebP optimization", "ESM image imports from src/assets/images/"]

key-files:
  created:
    - "src/assets/images/enakko-hero.png"
    - "src/assets/images/login-success.png"
    - "src/assets/images/monitoring-screen.png"
    - "src/assets/images/attendance-selection.png"
    - "src/assets/images/team-hands.png"
  modified:
    - "src/components/Hero.astro"
    - "src/components/HowItWorks.astro"

key-decisions:
  - "Replaced 90-line CSS tablet mockup with single Astro <Image> for authenticity"
  - "Image width 420px hero, 320px steps — optimal for layout and WebP compression"

patterns-established:
  - "Image pipeline: PNG in src/assets/images/ → ESM import → Astro <Image> → WebP in dist/_astro/"
  - "Kebab-case naming for all image assets"

requirements-completed: [WEB-P01, WEB-P02]

# Metrics
duration: 4min
completed: 2026-03-12
---

# Phase 19 Plan 01: Real Screenshots & Image Migration Summary

**Real app screenshots replace CSS mockup in Hero and add step companions to HowItWorks — 17MB PNG → 65KB WebP via Astro pipeline**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-12T19:50:01Z
- **Completed:** 2026-03-12T19:54:00Z
- **Tasks:** 2
- **Files modified:** 7 (5 images created, 2 components rewritten)

## Accomplishments
- Migrated 5 images from public/ to src/assets/images/ with kebab-case naming
- Replaced 90-line CSS tablet mockup in Hero with real Astro `<Image>` screenshot (2.13MB → 25KB WebP)
- Added companion screenshots to all 3 HowItWorks steps with Bahasa Indonesia alt text
- Total image payload reduced from ~17MB PNG to 65KB WebP (99.6% reduction)

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate images + rewrite Hero with real screenshot** - `c8cd418` (feat)
2. **Task 2: Add screenshot companions to HowItWorks steps** - `5b9e248` (feat)

## Files Created/Modified
- `src/assets/images/enakko-hero.png` - Hero screenshot source (2.13MB → 25KB WebP)
- `src/assets/images/login-success.png` - NFC login success screenshot (2.09MB → 19KB WebP)
- `src/assets/images/monitoring-screen.png` - Monitoring dashboard screenshot (9.81MB → 12KB WebP)
- `src/assets/images/attendance-selection.png` - Attendance selection screenshot (1.13MB → 9KB WebP)
- `src/assets/images/team-hands.png` - Team collaboration photo (reserved for Plan 02)
- `src/components/Hero.astro` - Replaced CSS mockup with `<Image>` component
- `src/components/HowItWorks.astro` - Added screenshot companions per step

## Decisions Made
- Replaced 90-line CSS tablet mockup with single `<Image>` tag — more authentic, simpler code
- Hero width=420px, HowItWorks width=320px — optimal for responsive layout and compression
- Kept all existing text, animations, and structure — only visual enhancement

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
- public/ images were untracked in git (never committed), so deletion couldn't be staged — but images were physically removed from disk, only favicon.svg remains

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- team-hands.png is in src/assets/images/ ready for About section (Plan 02)
- Image pipeline pattern established — Plan 02 can follow same ESM import + `<Image>` approach
- Build passes cleanly with all optimized images

## Self-Check: PASSED

- ✅ 19-01-SUMMARY.md exists
- ✅ All 5 images in src/assets/images/
- ✅ Commit c8cd418 (Task 1) exists
- ✅ Commit 5b9e248 (Task 2) exists
- ✅ public/ contains only favicon.svg

---
*Phase: 19-website-polish-real-screenshots-about-architecture-section-tech-icons*
*Completed: 2026-03-12*

# Domain Pitfalls — v3.0 Schedule Grid + Landing Website

**Domain:** NFC attendance kiosk (Flutter) + Marketing website (Astro.js)
**Researched:** 2026-03-12

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Breaking Data Layer During Grid Redesign
**What goes wrong:** While refactoring the 1,123-line `shift_scheduler_screen.dart`, developer "cleans up" data loading or save methods, introducing bugs in the Supabase ↔ SQLite sync.
**Why it happens:** The file is large and data + rendering code are interleaved. It's tempting to refactor everything at once.
**Consequences:** Broken schedule persistence for 4 production outlets. Lost schedules. Data inconsistency between Supabase and SQLite.
**Prevention:** Treat data methods as a black box. Extract rendering code ONLY. Copy data methods verbatim. Test save/load before AND after the redesign.
**Detection:** Schedule saved in app but not appearing in Supabase. Week navigation shows stale data. PDF export shows different data than grid.

### Pitfall 2: Manual Scroll Sync Removal Breaks Bulk Mode
**What goes wrong:** Removing the dual-ListView scroll sync code also removes the bulk-mode checkbox synchronization, where the employee list checkboxes need to align with the schedule rows.
**Why it happens:** The current bulk mode relies on `_employeeListController` and `_scheduleGridController` being in sync. `TableView` merges these into one scrollable.
**Consequences:** Bulk assign UI broken — checkboxes don't align with schedule rows.
**Prevention:** In `TableView`, the employee column IS column 0 of the same grid. Bulk checkboxes go inside `_buildEmployeeCell()`. The sync problem disappears because it's one viewport. But test bulk mode explicitly.
**Detection:** Checkboxes misaligned with rows. Selecting employee selects wrong person's schedule.

### Pitfall 3: `npm create astro@latest` Installs Astro 6
**What goes wrong:** Running `npm create astro@latest` pulls Astro 6 (current `latest` tag), not Astro 5. The `@astrojs/vercel@9.0.5` has peer dependency `astro ^5.0.0` and fails.
**Why it happens:** Astro 6 just released (6.0.4) and is now the `latest` dist tag. Most tutorials still reference Astro 5 patterns.
**Consequences:** Peer dependency conflicts. Integrations may not work. Time wasted debugging.
**Prevention:** After scaffolding, immediately pin: `npm install astro@^5.18.0`. Or use `npm create astro@5` if that syntax is supported. Verify `package.json` shows astro `^5.x` before installing integrations.
**Detection:** `npm install` warnings about peer dependencies. `@astrojs/tailwind` refusing to install. Build errors mentioning API changes.

### Pitfall 4: `two_dimensional_scrollables` TableView Missing Features
**What goes wrong:** Assuming `TableView` supports all the current grid features (tap handlers, context menus, bulk selection checkboxes inside cells) without verifying the API.
**Why it happens:** The package is official but relatively young (v0.3.x). Some features that seem obvious might not be implemented yet.
**Consequences:** Mid-redesign discovery that a critical interaction pattern isn't supported. Rollback or complex workarounds needed.
**Prevention:** Before starting the redesign, build a minimal proof-of-concept `TableView` with: (1) pinned row/column, (2) tap handler on cell, (3) checkbox inside cell, (4) conditional cell styling. If any of these fail, fall back to improving the current manual approach.
**Detection:** Cells not responding to taps. Checkboxes not rendering inside `TableViewCell`. Styling limitations.

## Moderate Pitfalls

### Pitfall 5: Forgetting Today Column Highlight in TableView
**What goes wrong:** The current grid calculates column widths dynamically in `LayoutBuilder`. When switching to `TableView`, the "today" column highlight is forgotten because the column builder doesn't know which day is today.
**Prevention:** Pass `DateTime.now()` comparison into `columnBuilder` decoration, or apply highlight in `cellBuilder` by checking if the column's date matches today.

### Pitfall 6: Tailwind v4 CSS-First Config Confusion
**What goes wrong:** Developer writes `tailwind.config.js` (v3 style) instead of using CSS `@theme` directives (v4 style). Custom brand colors don't work. Tutorials/StackOverflow answers reference v3 config.
**Prevention:** No `tailwind.config.js` file at all. All customization in `src/styles/global.css` using `@theme { }` and `@import "tailwindcss"`. Reference Tailwind v4 docs specifically, not generic Tailwind tutorials.

### Pitfall 7: Image Optimization Without `sharp`
**What goes wrong:** `<Image>` component in Astro falls back to passthrough (no optimization) without `sharp` installed. Images are served as original PNGs at full size.
**Prevention:** Install `sharp` as devDependency: `npm install -D sharp`. Verify in build output that images are being processed (look for WebP/AVIF generation logs).

### Pitfall 8: Astro `output: 'static'` vs `output: 'server'`
**What goes wrong:** Using `adapter: vercel()` without setting `output: 'static'` defaults to server-side rendering. The simple marketing page now runs on Vercel Serverless Functions instead of the CDN edge.
**Prevention:** Explicitly set `output: 'static'` in `astro.config.mjs`. This ensures the site is pre-rendered at build time and served as static files from Vercel's CDN (fastest possible).

### Pitfall 9: Row Height Mismatch After TableView Migration
**What goes wrong:** Current grid uses `height: 52` for employee cells and schedule cells. `TableView` uses `rowBuilder` with `TableSpan.extent`. If heights don't match exactly, cells misalign.
**Prevention:** Use the same `FixedTableSpanExtent(52)` in `rowBuilder`. The pinned employee column and scrollable grid share the same row definition, so this is guaranteed to be consistent (advantage of `TableView` over the current dual-ListView approach).

## Minor Pitfalls

### Pitfall 10: Google Fonts Flash on Website
**What goes wrong:** Using Google Fonts CDN causes a flash of unstyled text (FOUT) on page load.
**Prevention:** Use `@fontsource/inter` (self-hosted). Font files are bundled at build time — no network request, no flash.

### Pitfall 11: Missing `vercel.json` Cache Headers
**What goes wrong:** Static assets (images, fonts, CSS) served without cache headers. Repeat visitors download everything again.
**Prevention:** Add `vercel.json` with cache headers for static assets:
```json
{
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
    }
  ]
}
```

### Pitfall 12: APK Download Link Breaks When No GitHub Release Exists
**What goes wrong:** Website "Download APK" button links to a GitHub Releases URL that doesn't exist yet. Users get a 404.
**Prevention:** Ensure at least one GitHub Release with the APK is published before the website goes live. Use `/releases/latest` URL pattern which auto-redirects to the latest release.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Schedule grid refactor | Breaking data persistence (Pitfall 1) | Extract rendering only. Data methods = copy-paste verbatim. |
| Schedule grid refactor | TableView API gaps (Pitfall 4) | Build proof-of-concept FIRST before committing to full rewrite. |
| Schedule grid refactor | Bulk mode sync (Pitfall 2) | Test bulk assign end-to-end after migration. |
| Astro project init | Astro 6 installed (Pitfall 3) | Pin `astro@^5.18.0` immediately after scaffold. |
| Astro Tailwind setup | v3 vs v4 config confusion (Pitfall 6) | No tailwind.config.js. CSS-only config. Reference v4 docs. |
| Vercel deployment | SSR instead of static (Pitfall 8) | Explicit `output: 'static'` in config. |
| Website launch | APK link 404 (Pitfall 12) | Publish GitHub Release before website goes live. |

## Sources

- Existing `shift_scheduler_screen.dart`: analyzed 1,123 lines of code for scroll sync pattern, bulk mode, data layer
- `two_dimensional_scrollables` pub.dev page: API surface verified as TableView with pinnedRowCount/pinnedColumnCount
- npm registry: Astro dist-tags showing `latest: 6.0.4`, `legacy: 4.16.19`
- npm registry: `@astrojs/tailwind` peer deps confirmed `tailwindcss ^3.0.24` (no v4 support)
- npm registry: `@astrojs/vercel@9.0.5` peer deps confirmed `astro ^5.0.0`
- Tailwind v4 migration: CSS-first config via `@tailwindcss/vite` replaces JS config

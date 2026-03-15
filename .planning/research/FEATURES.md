# Feature Landscape — v3.0 Schedule Grid + Landing Website

**Domain:** NFC attendance kiosk admin tools + marketing website
**Researched:** 2026-03-12

## Table Stakes

Features that must exist for the redesign/website to be considered complete.

### Schedule Grid UI (Flutter)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Week-view grid (employees × days) | Core requirement — replaces current implementation | Medium | Already exists, needs visual redesign with `TableView` |
| Tap-to-assign shift cells | Primary interaction pattern | Low | Already works, needs better UX (inline vs dialog) |
| Pinned employee name column | Grid usability with horizontal scroll | Low | Currently manual, `TableView.pinnedColumnCount` handles it |
| Pinned day header row | Grid usability with vertical scroll | Low | Currently manual, `TableView.pinnedRowCount` handles it |
| Color-coded shift chips (Pagi/Siang/Sore/Libur) | Visual distinction between shifts | Low | Already exists (Blue/Amber/Orange/Red) |
| Sakit/Izin overlay display | Must show attendance status on grid | Low | Already works, carry over to new grid |
| Week navigation (← →) | Navigate between weeks | Low | Already exists |
| Save to Supabase + SQLite cache | Data persistence | Low | Already works, do not touch |
| PDF export | Schedule reporting | Low | Already works via PdfService |
| Bulk assign mode | Assign shift to multiple employees at once | Low | Already exists with checkbox selection |
| Auto-generate schedule | Template-based schedule generation | Low | Already exists with 2-shift/3-shift templates |

### Astro.js Landing Website

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Hero section with app mockup | First impression, product showcase | Low | Static content + optimized image |
| Feature showcase sections | Explain what ABSENKOK does | Low | 3-4 feature cards with icons/screenshots |
| Download APK button | Primary CTA | Low | Link to GitHub Releases URL |
| Developer watermark (Akmal) | Credit/attribution requirement | Low | Footer element |
| Responsive design (mobile + desktop) | Users browse on any device | Low | Tailwind responsive utilities |
| Fast page load (<2s) | Marketing page must be fast | Low | Astro zero-JS + image optimization |
| SEO meta tags | Discoverability | Low | `<head>` tags in BaseLayout |
| Sitemap.xml | Search engine indexing | Low | `@astrojs/sitemap` auto-generates |

## Differentiators

Features that elevate the redesign beyond "just works."

### Schedule Grid UI

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Animated cell transitions | Smooth shift assignment feels premium | Low | `AnimatedContainer` + `AnimatedSwitcher` |
| Inline shift picker (bottom sheet on cell tap) | Faster than dialog — tap cell → slide up picker → done | Low | Already using `showModalBottomSheet`, improve trigger UX |
| Today column highlight | Quick visual anchor for current day | Low | Conditional column background color |
| Leave balance badge on employee row | Show carry-over libur at a glance | Low | Already exists, improve visual design |
| Long-press to clear cell | Faster than tap → remove | Low | `GestureDetector.onLongPress` |
| Unsaved changes indicator (dot on save button) | Prevent accidental data loss | Low | Already exists |

### Astro.js Landing Website

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Scroll-reveal animations (CSS-only) | Apple/Stripe feel without JS | Low | CSS `@keyframes` + `IntersectionObserver` (tiny inline script) |
| OG image for social sharing | Professional look when shared on WhatsApp/social | Low | Static `og-image.png` in `<meta>` tags |
| Brand color consistency with app | Unified identity | Low | Same hex values from `AppColors` |
| Dark/light mode | Modern website feel | Medium | Tailwind `dark:` variants, `prefers-color-scheme` |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Drag-and-drop shift assignment (Flutter) | Complex gesture handling conflicts with scroll on tablets. `two_dimensional_scrollables` doesn't support drag across cells natively. Over-engineered for 14 employees. | Tap-to-assign with bottom sheet picker. Simpler, faster, works on tablets. |
| Real-time collaborative editing (Flutter) | Supabase Realtime could enable this but only 1 admin per outlet edits schedules. No concurrent editing scenario exists. | Single-user save-to-cloud pattern (current). |
| Monthly view (Flutter) | 14 employees × 30 days = 420 cells. Unreadable on tablet. | Weekly view only. Navigate weeks with ← →. |
| Blog on website | No content strategy, no writer, maintenance burden | Static marketing page only. Add blog later if needed. |
| Contact form on website | Needs backend, spam protection, email integration | WhatsApp link or email `mailto:` instead |
| Admin login on website | Separate concern — admin uses the app, not the website | Website is read-only marketing. No auth. |
| Analytics dashboard on website | Premature — measure traffic later | Add Vercel Analytics after launch if needed. Free tier. |
| Multi-language website | Indonesian audience only | Indonesian + maybe English hero. Not i18n framework. |

## Feature Dependencies

```
Schedule Grid:
  TableView widget → Cell builder → Shift picker → Save to Supabase
  (rendering layer)   (UI logic)    (interaction)   (data layer - KEEP AS-IS)

Website:
  BaseLayout → Header + Hero + Features + Download + Footer → Vercel deploy
  (scaffold)   (components - no dependencies between them)    (CI/CD)
```

## MVP Recommendation

### Schedule Grid — Ship With:
1. ✅ `TableView` with pinned employee column + day header (table stakes)
2. ✅ Color-coded shift cells with animated transitions (differentiator — low effort)
3. ✅ Today column highlight (differentiator — trivial)
4. ✅ All existing features preserved (bulk assign, auto-generate, PDF export, save)

### Website — Ship With:
1. ✅ Hero + Feature sections + Download button (table stakes)
2. ✅ Developer watermark (table stakes — explicit requirement)
3. ✅ Responsive design + SEO meta + Sitemap (table stakes)
4. ✅ OG image for social sharing (differentiator — trivial)

### Defer:
- **Dark mode** (website): Nice-to-have, not critical for launch. Add post-launch.
- **Scroll-reveal animations** (website): Polish after core content is right.
- **Long-press to clear** (grid): Test tap-to-clear first, add long-press if users request it.

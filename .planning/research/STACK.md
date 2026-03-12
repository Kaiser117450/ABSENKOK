# Technology Stack — v3.0 Schedule Grid + Landing Website

**Project:** Absensi Enakko (ABSENKOK)
**Researched:** 2026-03-12
**Scope:** NEW additions only — Schedule Grid UI (Flutter) + Astro.js Marketing Website

---

## Part 1: Flutter Schedule Grid Redesign

### Recommended Addition

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `two_dimensional_scrollables` | ^0.3.8 | 2D scrolling grid with pinned rows/columns | Official Flutter team package. Replaces manual dual-ListView sync with true 2D scrolling. Pinned left employee column + pinned top day header = exactly the schedule grid pattern needed. Eliminates 40+ lines of manual `ScrollController` sync code. |

**Confidence:** HIGH — verified on pub.dev, SDK ^3.9.0 compatible with project's Dart 3.11.0, Flutter >=3.35.0 compatible with 3.41.1

### What NOT to Add

| Rejected Package | Why Not |
|------------------|---------|
| `pluto_grid` v8.1.0 | Heavy data-grid overkill for a 14-employee × 7-day grid. Designed for Excel-like spreadsheets, not shift scheduling. |
| `data_table_2` v2.7.2 | Wraps Material `DataTable` — no 2D scroll support, limited to single-axis scrolling with fixed headers. |
| `syncfusion_flutter_datagrid` v32.2.9 | Requires commercial license. Way too heavy for this simple use case. |
| `linked_scroll_controller` v0.2.0 | SDK constraint `>=2.12.0-0 <3.0.0` — **incompatible with Dart 3.x**. Abandoned package. |
| `flutter_animate` v4.5.2 | Nice-to-have but unnecessary. Built-in `AnimatedContainer`, `AnimatedSwitcher`, `AnimatedScale` provide all the cell transition animations needed. Already have `confetti` for celebrations. |
| `table_calendar` v3.2.0 | Calendar widget, not a schedule grid. Wrong abstraction. |
| `flutter_staggered_grid_view` v0.7.0 | SDK `>=2.12.0 <3.0.0` — incompatible with Dart 3.x. Also designed for Pinterest-style layouts, not data grids. |

### Architecture: Why `two_dimensional_scrollables` Over Current Approach

The existing `shift_scheduler_screen.dart` (1,123 lines) manually synchronizes two `ListView.builder` widgets with a `bool _isSyncing` flag and paired `ScrollController.jumpTo()` calls. This works but is fragile:

```dart
// CURRENT: Manual sync (fragile, 40+ lines of boilerplate)
_employeeListController.addListener(() {
  if (!_isSyncing && _scheduleGridController.hasClients) {
    _isSyncing = true;
    _scheduleGridController.jumpTo(_employeeListController.offset);
    _isSyncing = false;
  }
});
```

`two_dimensional_scrollables` provides `TableView` which handles this natively:

```dart
// NEW: True 2D scrolling with pinned row/column
TableView(
  pinnedRowCount: 1,    // Header row (Sen, Sel, Rab...)
  pinnedColumnCount: 1, // Employee name column
  cellBuilder: (context, vicinity) {
    // vicinity.row = employee index, vicinity.column = day index
    return _buildCell(vicinity);
  },
  columnCount: 8, // 1 name + 7 days
  rowCount: employees.length + 1, // +1 header
  columnBuilder: (index) => TableSpan(extent: index == 0
    ? FixedTableSpanExtent(120) // employee column
    : FractionalTableSpanExtent(1/7)), // day columns
  rowBuilder: (index) => TableSpan(extent: FixedTableSpanExtent(56)),
)
```

**Benefits:**
- Eliminates manual scroll sync entirely
- True diagonal scrolling (current impl only syncs vertical)
- Better performance — single viewport instead of two competing ListViews
- Pinned columns/rows are first-class features
- From Flutter team = maintained long-term

### Use Built-In Flutter for Everything Else

| Built-in Feature | Use For |
|-------------------|---------|
| `AnimatedContainer` | Smooth color/size transitions when shift assigned to cell |
| `AnimatedSwitcher` | Cross-fade between empty cell → shift chip |
| `AnimatedScale` | Pop-in effect on tap-assign |
| `showModalBottomSheet` | Shift picker (Pagi/Siang/Sore/Libur) — already using this |
| `GestureDetector` + `InkWell` | Tap-to-assign cells — already using this |
| `LayoutBuilder` | Responsive column widths — already using this |

### Existing Dependencies That Stay Unchanged

These are already in `pubspec.yaml` and remain as-is for the schedule grid:
- `flutter_riverpod: ^2.6.1` — state management (AppProvider for schedule data)
- `supabase_flutter: ^2.8.4` — schedule CRUD to Supabase
- `sqflite: ^2.4.1` — ScheduleSQLiteService offline cache
- `intl: ^0.19.0` — date formatting for grid headers
- `pdf: ^3.10.8` + `printing: ^5.13.4` — PDF export of schedule
- `screenshot: ^3.0.0` — schedule screenshot export
- `google_fonts: ^6.2.1` — typography
- `uuid: ^4.5.1` — entry ID generation

### Installation (Flutter)

```yaml
# Add to pubspec.yaml under dependencies:
dependencies:
  # ... existing deps unchanged ...
  
  # Schedule grid 2D scrolling (official Flutter team)
  two_dimensional_scrollables: ^0.3.8
```

```bash
flutter pub get
```

---

## Part 2: Astro.js Landing Website

### Recommended Stack

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `astro` | ^5.18.0 | Static site framework | Astro 5 is battle-tested with 100+ minor releases. Astro 6 (6.0.4) just launched — too new, integrations not all updated yet. Zero JS by default = fastest possible landing page. |
| `tailwindcss` | ^4.2.0 | CSS framework | Current major version. CSS-first config (no `tailwind.config.js`) is simpler for static sites. Just `@import "tailwindcss"` in CSS. |
| `@tailwindcss/vite` | ^4.2.0 | Tailwind v4 Vite integration | Astro runs on Vite. This is the official way to use Tailwind v4 with Vite-based frameworks. No `@astrojs/tailwind` needed. |
| `@astrojs/vercel` | ^9.0.5 | Vercel deployment adapter | Peer dependency: `astro ^5.0.0`. Handles static + SSR deploy to Vercel. For a landing page, use `output: 'static'` (default). |
| `@astrojs/sitemap` | ^3.7.0 | SEO sitemap generation | Auto-generates sitemap.xml. Essential for discoverability. |
| `sharp` | ^0.34.0 | Image optimization | Powers Astro's built-in `<Image>` component. Auto-generates WebP/AVIF, responsive sizes. Install as devDependency. |
| `@fontsource/inter` | ^5.2.0 | Typography | Self-hosted Inter font. Clean sans-serif matching Apple/Stripe minimalist aesthetic. No Google Fonts network request. |

**Confidence:** HIGH — all versions verified via `npm view`, peer dependencies checked

### Why Astro 5, Not Astro 6

| Factor | Astro 5 (^5.18.0) | Astro 6 (6.0.4) |
|--------|-------------------|------------------|
| Stability | 120+ releases, battle-tested | 4 releases, brand new |
| `@astrojs/tailwind` | ✅ Compatible (peers ^3-5) | ❌ Not compatible |
| `@astrojs/vercel` | ✅ v9.0.5 (stable) | ⚠️ v10.0.0 (just released) |
| Community resources | Extensive tutorials, templates | Minimal |
| Risk | Low | Medium-High |
| Dist tag | Available as `astro@5.18.1` | `latest` tag |

**Decision:** Astro 5. The landing page is simple — we don't need Astro 6's new features. Pin to `^5.18.0` for stability.

### Why Tailwind v4, Not v3

| Factor | Tailwind v4 | Tailwind v3 |
|--------|-------------|-------------|
| Config | CSS-first (`@import "tailwindcss"`) | JS config file (`tailwind.config.js`) |
| Setup with Astro | `@tailwindcss/vite` as Vite plugin | `@astrojs/tailwind` integration |
| Performance | Faster builds (Rust-based) | Slower (JS-based) |
| Status | Current major version | Legacy |
| Learning curve | Simpler for new projects | More docs/examples available |

**Decision:** Tailwind v4. New project, no migration burden. CSS-first config is cleaner. Works natively via Vite plugin.

### What NOT to Add

| Rejected Tech | Why Not |
|---------------|---------|
| React / Svelte / Vue | Static landing page — no interactive components needed. Astro's `.astro` components + scoped CSS + Tailwind handle everything. Zero JS shipped = fastest page. |
| `@astrojs/tailwind` | This integration targets Tailwind v3. We're using v4 with `@tailwindcss/vite` directly. |
| Any CMS (Contentful, Sanity, etc.) | Marketing copy is hardcoded. 5 sections on one page — no dynamic content. |
| `framer-motion` / animation library | CSS animations + Tailwind's built-in `animate-*` utilities + `@keyframes` are sufficient for a landing page. Keep JS bundle at zero. |
| `astro-icon` v1.1.5 | Adds dependency complexity. Inline SVGs or a small icon sprite are simpler for <10 icons on a marketing page. |
| `@astrojs/mdx` | No blog, no markdown content. Pure `.astro` components. |
| Headless UI / Radix | No interactive components (no dropdowns, modals, etc.). Static content only. |

### Astro Configuration

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://absenkok.vercel.app', // Update with real domain
  output: 'static',
  adapter: vercel(),
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
  image: {
    service: { entrypoint: 'astro/assets/services/sharp' },
  },
});
```

### Project Structure

```
absenkok-website/
├── astro.config.mjs
├── package.json
├── tsconfig.json
├── public/
│   ├── favicon.svg
│   ├── og-image.png          # Open Graph social preview
│   └── absenkok-logo.svg     # Brand logo
├── src/
│   ├── assets/
│   │   └── images/           # Optimized via <Image>
│   │       ├── hero-mockup.png
│   │       ├── feature-nfc.png
│   │       ├── feature-schedule.png
│   │       └── feature-reports.png
│   ├── components/
│   │   ├── Header.astro
│   │   ├── Hero.astro
│   │   ├── Features.astro
│   │   ├── Download.astro
│   │   ├── Footer.astro
│   │   └── DeveloperWatermark.astro
│   ├── layouts/
│   │   └── BaseLayout.astro
│   ├── pages/
│   │   └── index.astro
│   └── styles/
│       └── global.css         # @import "tailwindcss"; + custom
└── vercel.json                # Optional: redirects, headers
```

### Installation (Astro Website)

```bash
# Create project directory
mkdir absenkok-website && cd absenkok-website

# Init Astro project
npm create astro@latest . -- --template minimal --typescript strict

# Install core (pin to Astro 5)
npm install astro@^5.18.0

# Install Tailwind v4
npm install tailwindcss@^4.2.0 @tailwindcss/vite@^4.2.0

# Install integrations
npm install @astrojs/vercel@^9.0.5 @astrojs/sitemap@^3.7.0

# Install font
npm install @fontsource/inter@^5.2.0

# Install image optimizer (dev dep)
npm install -D sharp@^0.34.0

# TypeScript checking (dev dep)
npm install -D @astrojs/check@^0.9.0 typescript
```

### Full `package.json` Dependencies

```json
{
  "dependencies": {
    "astro": "^5.18.0",
    "tailwindcss": "^4.2.0",
    "@tailwindcss/vite": "^4.2.0",
    "@astrojs/vercel": "^9.0.5",
    "@astrojs/sitemap": "^3.7.0",
    "@fontsource/inter": "^5.2.0"
  },
  "devDependencies": {
    "sharp": "^0.34.0",
    "@astrojs/check": "^0.9.0",
    "typescript": "^5.7.0"
  }
}
```

---

## Integration Points

### Flutter ↔ Website Integration

| Touch Point | How |
|-------------|-----|
| APK download | Website "Download" button → GitHub Releases URL (e.g., `github.com/user/repo/releases/latest/download/absenkok.apk`) |
| Brand consistency | Website uses same `AppColors.primary` (#DC2626 red) and warm amber accents from Flutter app's `theme.dart` |
| Feature screenshots | Capture app screenshots from Flutter, optimize with `sharp` in Astro |
| No API connection | Website is 100% static. No Supabase calls, no backend connection. Completely independent deployment. |

### Color Token Mapping (Flutter → Tailwind)

```css
/* global.css — map Flutter AppColors to Tailwind custom properties */
@theme {
  --color-brand-primary: #DC2626;     /* AppColors.primary */
  --color-brand-dark: #B91C1C;        /* AppColors.primaryDark */
  --color-brand-light: #FEE2E2;       /* AppColors.primaryLight */
  --color-brand-accent: #F59E0B;      /* AppColors.accent */
  --color-brand-accent-dark: #D97706; /* AppColors.accentDark */
  --color-brand-accent-light: #FEF3C7; /* AppColors.accentLight */
}
```

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Flutter grid | `two_dimensional_scrollables` | Manual dual-ListView sync (current) | Current approach works but fragile. The official package is cleaner, more performant, and eliminates manual sync code. This is a redesign — take the opportunity. |
| Flutter grid | `two_dimensional_scrollables` | `pluto_grid` v8.1.0 | Massive dependency (300+ KB) for a 14×7 grid. Enterprise spreadsheet features we don't need. |
| Flutter animation | Built-in (`AnimatedContainer` etc.) | `flutter_animate` v4.5.2 | Extra dependency for simple fade/scale effects. Built-in animations are sufficient and already used elsewhere in the app. |
| Web framework | Astro 5 | Astro 6 | Too new (6.0.4), integration ecosystem not updated. `@astrojs/tailwind` breaks. |
| Web framework | Astro 5 | Next.js | Massive overkill for a static marketing page. Astro ships zero JS by default. Next.js ships React runtime. |
| Web framework | Astro 5 | Plain HTML/CSS | Works but no image optimization, no component reuse, no sitemap generation. Astro gives these for free. |
| CSS framework | Tailwind v4 | Tailwind v3 | v3 works but is legacy. New project = use current version. CSS-first config is simpler. |
| CSS framework | Tailwind v4 | Vanilla CSS | More code, no utility classes, slower development. For a marketing page with responsive design, Tailwind is 3-5x faster. |
| Deployment | Vercel | Netlify | Both work. Vercel has better Astro integration (`@astrojs/vercel`), faster builds, better analytics. |
| Font | Inter (self-hosted) | Google Fonts CDN | Self-hosted = no external network requests = faster FCP. `@fontsource` makes this trivial. |

---

## Version Compatibility Matrix

### Flutter (Verified)

| Package | Version | Dart SDK | Flutter SDK | Project Compatible? |
|---------|---------|----------|-------------|---------------------|
| `two_dimensional_scrollables` | 0.3.8 | ^3.9.0 | >=3.35.0 | ✅ Dart 3.11.0 + Flutter 3.41.1 |

### Astro Website (Verified)

| Package | Version | Peers | Compatible? |
|---------|---------|-------|-------------|
| `astro` | ^5.18.0 | — | ✅ Base |
| `@tailwindcss/vite` | ^4.2.0 | Vite (bundled with Astro) | ✅ |
| `@astrojs/vercel` | ^9.0.5 | astro ^5.0.0 | ✅ |
| `@astrojs/sitemap` | ^3.7.0 | (no peer constraint) | ✅ |
| `sharp` | ^0.34.0 | (native binary) | ✅ |
| `@astrojs/check` | ^0.9.0 | (dev tool) | ✅ |

---

## Sources

- pub.dev API: `two_dimensional_scrollables` v0.3.8 — verified SDK/Flutter constraints across all versions
- pub.dev API: `linked_scroll_controller` v0.2.0 — confirmed SDK <3.0.0 incompatibility
- pub.dev API: `flutter_animate` v4.5.2, `pluto_grid` v8.1.0, `data_table_2` v2.7.2
- npm registry: `astro` 6.0.4 (latest), 5.18.1 (last v5), dist-tags confirmed
- npm registry: `@astrojs/vercel` 9.0.5 peers `astro ^5.0.0`, 10.0.0 peers `astro ^6.0.0-alpha.0`
- npm registry: `@astrojs/tailwind` 6.0.2 peers `astro ^3-5, tailwindcss ^3.0.24`
- npm registry: `tailwindcss` 4.2.1, `@tailwindcss/vite` 4.2.1
- npm registry: `sharp` 0.34.5, `@astrojs/sitemap` 3.7.1, `@astrojs/check` 0.9.7
- Project `pubspec.yaml`: SDK `>=3.3.0 <4.0.0`, existing dependencies catalog
- Project `flutter --version`: Flutter 3.41.1, Dart 3.11.0
- Existing `shift_scheduler_screen.dart`: 1,123 lines, manual scroll sync pattern analyzed

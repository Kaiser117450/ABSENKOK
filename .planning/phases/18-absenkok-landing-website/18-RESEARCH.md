# Phase 18: ABSENKOK Landing Website - Research

**Researched:** 2026-03-12
**Domain:** Static marketing website (Astro 5 + Tailwind CSS v4 + Vercel)
**Confidence:** HIGH

## Summary

Phase 18 is a **greenfield static website** in a **separate repository** from the Flutter app. The website is a single-page marketing landing for ABSENKOK — an NFC attendance kiosk system. It has 5 sections (Hero, Features, How It Works, Download CTA, Footer), all copy in Bahasa Indonesia, zero JavaScript shipped to the browser, and deployment to Vercel.

The stack is well-researched and locked: **Astro 5** (NOT Astro 6 — too new), **Tailwind CSS v4** via `@tailwindcss/vite` (NOT `@astrojs/tailwind` which is Tailwind v3), self-hosted Inter font via `@fontsource`, `sharp` for build-time image optimization, and `@astrojs/sitemap` for SEO. Brand colors are mapped from the Flutter app's `AppColors` in `theme.dart` (primary red `#DC2626`, accent amber `#F59E0B`, clean white backgrounds).

This is a low-risk, low-complexity phase. All content is hardcoded (no CMS), no backend connection, no dynamic data. The only integration point with the Flutter app is a download link pointing to GitHub Releases. The critical pitfall is that `npm create astro@latest` now scaffolds **Astro 6** (the `latest` dist-tag is `6.0.4`), so Astro 5 must be pinned immediately after project creation.

**Primary recommendation:** Scaffold manually or pin `astro@^5.18.0` immediately. Use Tailwind v4 CSS-first config (`@theme {}` directives, NO `tailwind.config.js`). Ship zero JS. Deploy static to Vercel.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WEB-01 | Hero section dengan app mockup dalam frame tablet dan tagline ABSENKOK | Astro `<Image>` component for optimized mockup image, CSS-only tablet frame with `rounded-2xl shadow-2xl`, Tailwind responsive grid layout |
| WEB-02 | Feature showcase section menampilkan 4-6 fitur utama dengan ikon/screenshot | Inline SVG icons (no `astro-icon` dependency), Astro `<Image>` for screenshots, responsive grid `grid-cols-1 md:grid-cols-2 lg:grid-cols-3` |
| WEB-03 | "How It Works" section menjelaskan 3 langkah penggunaan app | Pure HTML/CSS numbered steps with Tailwind, no JS needed |
| WEB-04 | Tombol download APK mengarah ke GitHub Releases | Simple `<a>` tag to `github.com/{user}/{repo}/releases/latest/download/{filename}.apk` — verify release exists before launch |
| WEB-05 | Watermark/credit developer "Akmal" di footer | Static text in `Footer.astro` component |
| WEB-06 | Responsive design (mobile + tablet + desktop) | Tailwind v4 responsive breakpoints (`sm:`, `md:`, `lg:`), mobile-first approach |
| WEB-07 | Semua copy dalam Bahasa Indonesia | All marketing text hardcoded in Bahasa Indonesia in `.astro` component files |
| WEB-08 | Page load < 2 detik, zero JavaScript shipped | Astro `output: 'static'` ships zero JS by default, `sharp` optimizes images to WebP, self-hosted fonts eliminate network requests |
| WEB-09 | SEO meta tags + sitemap.xml | BaseLayout.astro `<head>` with OG/Twitter meta tags, `@astrojs/sitemap` auto-generates sitemap.xml |
| WEB-10 | Deploy ke Vercel | `@astrojs/vercel` adapter (optional for static), Vercel auto-detects Astro, `vercel.json` for cache headers |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `astro` | ^5.18.0 | Static site framework | Astro 5 is battle-tested (120+ releases). Ships zero JS by default = fastest page load. Astro 6 (`latest: 6.0.4`) is too new — integrations not all updated. |
| `tailwindcss` | ^4.2.0 | CSS utility framework | Current major version. CSS-first config (no JS config file). Rust-based engine = fast builds. |
| `@tailwindcss/vite` | ^4.2.0 | Tailwind v4 Vite plugin | Official way to use Tailwind v4 with Vite-based frameworks (Astro runs on Vite). Replaces deprecated `@astrojs/tailwind`. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@astrojs/vercel` | ^9.0.5 | Vercel deployment adapter | Peer dep: `astro ^5.0.0`. Optional for pure static, but provides Vercel-specific optimizations. |
| `@astrojs/sitemap` | ^3.7.0 | Auto-generate sitemap.xml | SEO requirement (WEB-09). Add `site` URL in `astro.config.mjs`. |
| `sharp` | ^0.34.0 (devDep) | Build-time image optimization | Powers Astro's `<Image>` component. Generates WebP/AVIF, responsive sizes. |
| `@fontsource/inter` | ^5.2.0 | Self-hosted Inter font | Zero network request for fonts. Eliminates FOUT (Flash of Unstyled Text). Clean sans-serif for Apple/Stripe aesthetic. |
| `@astrojs/check` | ^0.9.0 (devDep) | TypeScript checking | Catches type errors in `.astro` files during development. |
| `typescript` | ^5.7.0 (devDep) | TypeScript support | Required by `@astrojs/check`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Astro 5 | Astro 6 (`6.0.4`) | Astro 6 is `latest` but only 4 releases old. `@astrojs/vercel@9` incompatible (needs `@10`). Risk: integration breakage. |
| Tailwind v4 | Tailwind v3 | v3 works but is legacy. Needs `tailwind.config.js` + `@astrojs/tailwind`. v4 CSS-first config is simpler for new projects. |
| Astro | Plain HTML/CSS | Works but no image optimization, no component reuse, no auto-sitemap. Astro gives these free. |
| Astro | Next.js | Massive overkill. Ships React runtime. For a static marketing page, Astro is 10x lighter. |
| `@fontsource/inter` | Google Fonts CDN | CDN adds network dependency + FOUT. Self-hosted is faster FCP. |
| Inline SVGs | `astro-icon` v1.1.5 | Extra dependency for <10 icons. Inline SVGs are simpler and lighter. |
| `@astrojs/vercel` | No adapter (pure static) | For `output: 'static'`, Vercel auto-detects Astro without adapter. Adapter adds Vercel-specific optimizations but is optional. |

**Installation:**

```bash
# In C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\

# Option A: Scaffold then pin (RECOMMENDED)
npm create astro@latest . -- --template minimal --typescript strict
npm install astro@^5.18.0   # PIN to Astro 5 immediately!

# Install Tailwind v4
npm install tailwindcss@^4.2.0 @tailwindcss/vite@^4.2.0

# Install integrations
npm install @astrojs/vercel@^9.0.5 @astrojs/sitemap@^3.7.0

# Install font
npm install @fontsource/inter@^5.2.0

# Dev dependencies
npm install -D sharp@^0.34.0 @astrojs/check@^0.9.0 typescript@^5.7.0
```

**Full `package.json` dependencies:**

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

## Architecture Patterns

### Recommended Project Structure

```
absenkok-website/                          # C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\
├── astro.config.mjs                       # Astro + Tailwind v4 + Vercel + Sitemap config
├── package.json
├── tsconfig.json
├── vercel.json                            # Cache headers for static assets
├── public/
│   ├── favicon.svg                        # ABSENKOK brand favicon
│   ├── og-image.png                       # 1200x630 Open Graph social preview
│   └── absenkok-logo.svg                  # Brand logo SVG
├── src/
│   ├── assets/
│   │   └── images/
│   │       ├── hero-mockup.png            # App screenshot in tablet frame
│   │       ├── feature-nfc.png            # Feature screenshots (optional)
│   │       ├── feature-schedule.png
│   │       └── feature-reports.png
│   ├── components/
│   │   ├── Header.astro                   # Logo + nav (optional anchor links)
│   │   ├── Hero.astro                     # WEB-01: Tablet mockup + tagline + CTA
│   │   ├── Features.astro                 # WEB-02: 4-6 feature cards with icons
│   │   ├── HowItWorks.astro              # WEB-03: 3 numbered steps
│   │   ├── Download.astro                 # WEB-04: Download APK CTA section
│   │   └── Footer.astro                   # WEB-05: "Akmal" credit + links
│   ├── layouts/
│   │   └── BaseLayout.astro               # <html>, <head> (meta/SEO), <body> wrapper
│   ├── pages/
│   │   └── index.astro                    # Single page — assembles all components
│   └── styles/
│       └── global.css                     # @import "tailwindcss" + @theme brand colors
└── .gitignore
```

### Pattern 1: Astro Configuration (astro.config.mjs)

**What:** Central config wiring Tailwind v4 as Vite plugin, Vercel adapter, and sitemap.
**When:** Project initialization — create this file first.

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://absenkok.vercel.app',  // Update with real Vercel URL after first deploy
  output: 'static',                      // CRITICAL: pre-rendered static HTML, no serverless
  adapter: vercel(),                      // Optional for static, but provides Vercel optimizations
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],            // Tailwind v4 via Vite plugin (NOT @astrojs/tailwind)
  },
});
```

### Pattern 2: Tailwind v4 CSS-First Config with Brand Colors

**What:** CSS-only Tailwind customization using `@theme` directive. Maps Flutter `AppColors` to Tailwind custom properties.
**When:** Global styles setup — no `tailwind.config.js` file.

```css
/* src/styles/global.css */
@import "tailwindcss";
@import "@fontsource/inter/400.css";
@import "@fontsource/inter/500.css";
@import "@fontsource/inter/600.css";
@import "@fontsource/inter/700.css";
@import "@fontsource/inter/800.css";

/* Brand color tokens — mapped from Flutter AppColors in theme.dart */
@theme {
  --font-sans: 'Inter', sans-serif;

  /* Primary (Red) */
  --color-brand-primary: #DC2626;
  --color-brand-dark: #B91C1C;
  --color-brand-light: #FEE2E2;

  /* Accent (Amber) */
  --color-brand-accent: #F59E0B;
  --color-brand-accent-dark: #D97706;
  --color-brand-accent-light: #FEF3C7;

  /* Surfaces */
  --color-brand-surface: #F9FAFB;
  --color-brand-border: #E5E7EB;

  /* Text */
  --color-brand-text: #111827;
  --color-brand-text-secondary: #6B7280;
  --color-brand-text-muted: #9CA3AF;
}
```

**Usage in templates:** `bg-brand-primary`, `text-brand-dark`, `border-brand-border`, etc.

### Pattern 3: BaseLayout with SEO Meta Tags

**What:** Layout component containing `<head>` with all SEO/OG meta tags.
**When:** Every page inherits this layout (only one page for this project).

```astro
---
// src/layouts/BaseLayout.astro
interface Props {
  title: string;
  description: string;
}

const { title, description } = Astro.props;
const canonicalURL = new URL(Astro.url.pathname, Astro.site);
---

<!doctype html>
<html lang="id">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link rel="canonical" href={canonicalURL} />

    <!-- SEO -->
    <title>{title}</title>
    <meta name="description" content={description} />

    <!-- Open Graph -->
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content="/og-image.png" />
    <meta property="og:url" content={canonicalURL} />
    <meta property="og:type" content="website" />
    <meta property="og:locale" content="id_ID" />

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content="/og-image.png" />

    <!-- Global CSS (Tailwind + fonts) -->
    <style is:global>
      @import "../styles/global.css";
    </style>
  </head>
  <body class="bg-white text-brand-text font-sans antialiased">
    <slot />
  </body>
</html>
```

### Pattern 4: Astro Component with Optimized Image

**What:** Using Astro's built-in `<Image>` component for automatic WebP conversion and responsive sizing.
**When:** Every image in `src/assets/` — NOT for images in `public/`.

```astro
---
// src/components/Hero.astro
import { Image } from 'astro:assets';
import heroMockup from '../assets/images/hero-mockup.png';
---

<section class="relative overflow-hidden bg-white py-20 lg:py-32">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="grid grid-cols-1 gap-12 lg:grid-cols-2 lg:items-center">
      <!-- Text content -->
      <div>
        <h1 class="text-4xl font-extrabold tracking-tight text-brand-text sm:text-5xl lg:text-6xl">
          Absensi NFC untuk <span class="text-brand-primary">Restoran Modern</span>
        </h1>
        <p class="mt-6 text-lg leading-8 text-brand-text-secondary">
          Tap kartu, hadir tercatat. ABSENKOK mengelola kehadiran karyawan
          dengan NFC, jadwal shift otomatis, dan laporan real-time.
        </p>
        <a href="https://github.com/user/repo/releases/latest"
           class="mt-8 inline-flex items-center gap-2 rounded-full bg-brand-primary
                  px-8 py-3.5 text-white font-semibold shadow-lg
                  hover:bg-brand-dark transition-colors duration-200">
          Download APK
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
          </svg>
        </a>
      </div>
      <!-- Tablet mockup image -->
      <div class="relative">
        <div class="rounded-2xl bg-gray-900 p-3 shadow-2xl ring-1 ring-gray-900/10">
          <Image
            src={heroMockup}
            alt="ABSENKOK app - tampilan jadwal shift karyawan"
            class="rounded-xl"
            width={600}
            quality={85}
          />
        </div>
      </div>
    </div>
  </div>
</section>
```

### Pattern 5: Single-Page Assembly

**What:** The `index.astro` page imports and assembles all section components.
**When:** This is the only page — keeps each section in its own maintainable file.

```astro
---
// src/pages/index.astro
import BaseLayout from '../layouts/BaseLayout.astro';
import Header from '../components/Header.astro';
import Hero from '../components/Hero.astro';
import Features from '../components/Features.astro';
import HowItWorks from '../components/HowItWorks.astro';
import Download from '../components/Download.astro';
import Footer from '../components/Footer.astro';
---

<BaseLayout
  title="ABSENKOK — Sistem Absensi NFC untuk Restoran"
  description="Kelola kehadiran karyawan restoran dengan NFC tap, jadwal shift otomatis, dan laporan real-time. Download gratis."
>
  <Header />
  <main>
    <Hero />
    <Features />
    <HowItWorks />
    <Download />
  </main>
  <Footer />
</BaseLayout>
```

### Pattern 6: Vercel Cache Headers

**What:** Static asset cache headers for optimal performance on repeat visits.

```json
// vercel.json
{
  "headers": [
    {
      "source": "/_astro/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    },
    {
      "source": "/(.*).webp",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ]
}
```

### Anti-Patterns to Avoid

- **Adding React/Svelte/Vue islands:** Static landing page needs zero interactivity. Every framework island ships JS runtime. Use pure `.astro` components + Tailwind only.
- **Creating `tailwind.config.js`:** This is Tailwind v3 pattern. Tailwind v4 uses CSS-first config via `@theme {}` in `global.css`. No JS config file.
- **Using `@astrojs/tailwind` integration:** This targets Tailwind v3. Use `@tailwindcss/vite` as a Vite plugin instead.
- **Fetching data from Supabase:** Website is 100% static brochure. No backend connection. All copy is hardcoded.
- **Using `output: 'server'` or `output: 'hybrid'`:** Forces serverless functions on Vercel. Use `output: 'static'` for CDN-edge delivery = fastest possible.
- **Putting images in `public/` for optimization:** Only `src/assets/` images get processed by `<Image>` component. `public/` images are served as-is.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image optimization (WebP/AVIF) | Custom sharp pipeline | Astro `<Image>` component + `sharp` devDep | Automatic format conversion, responsive sizes, lazy loading. 3 lines vs 30. |
| Sitemap generation | Manual `sitemap.xml` | `@astrojs/sitemap` integration | Auto-discovers all pages, updates on build. Zero maintenance. |
| CSS utility framework | Custom CSS classes | Tailwind v4 utility classes | Responsive design, consistent spacing, dark mode support built-in. |
| Font loading | Manual `@font-face` declarations | `@fontsource/inter` | Pre-packaged font files, correct `unicode-range`, no CDN dependency. |
| Tablet mockup frame | Complex SVG/canvas mock | CSS `rounded-2xl bg-gray-900 p-3 shadow-2xl` | Simple CSS padding + border-radius + shadow creates convincing device frame. |
| SEO meta tags | Scattered `<meta>` tags per page | BaseLayout.astro props pattern | Single source of truth for all SEO tags, type-safe with Astro props. |
| Icon system | Icon font or sprite sheet | Inline SVG in components | <10 icons total. Inline SVGs are smaller, tree-shakeable, style-able with Tailwind. |

**Key insight:** For a single-page static site, the best architecture is the simplest one. Astro + Tailwind handle 95% of the work. Every added dependency is overhead.

## Common Pitfalls

### Pitfall 1: `npm create astro@latest` Installs Astro 6
**What goes wrong:** Running `npm create astro@latest` pulls Astro 6 (current `latest` tag is `6.0.4`). The `@astrojs/vercel@9.0.5` has peer dependency `astro ^5.0.0` and fails.
**Why it happens:** Astro 6 just released and became the `latest` dist-tag. Most tutorials reference Astro 5.
**How to avoid:** After scaffolding, immediately pin: `npm install astro@^5.18.0`. Verify `package.json` shows `^5.18.0` before installing other packages.
**Warning signs:** `npm install` peer dependency warnings. Build errors mentioning unknown API.

### Pitfall 2: Tailwind v4 Config Confusion (JS vs CSS)
**What goes wrong:** Developer creates `tailwind.config.js` (v3 style) instead of using CSS `@theme {}` directive (v4 style). Custom brand colors don't work. StackOverflow answers reference v3.
**Why it happens:** Most existing Tailwind tutorials and answers target v3. V4's CSS-first approach is fundamentally different.
**How to avoid:** No `tailwind.config.js` file at all. All customization in `src/styles/global.css` using `@theme { }` and `@import "tailwindcss"`.
**Warning signs:** Custom colors like `bg-brand-primary` not applying. Tailwind classes not being generated.

### Pitfall 3: Image Optimization Not Working
**What goes wrong:** `<Image>` component falls back to passthrough (no optimization) without `sharp` installed. Images served as original PNGs at full size.
**Why it happens:** `sharp` is a native binary — it's not included in Astro by default.
**How to avoid:** Install `sharp` as devDependency: `npm install -D sharp@^0.34.0`. Verify build output shows image processing logs (WebP/AVIF generation).
**Warning signs:** Build output shows no image processing. Page loads >2s due to unoptimized images.

### Pitfall 4: `output: 'static'` vs `output: 'server'` Confusion
**What goes wrong:** Using `adapter: vercel()` without explicitly setting `output: 'static'` may default to SSR. The marketing page runs on serverless functions instead of CDN edge.
**Why it happens:** Adapter presence can imply SSR mode in some configurations.
**How to avoid:** Explicitly set `output: 'static'` in `astro.config.mjs`. Verify build output says "static" not "server".
**Warning signs:** Vercel dashboard shows Serverless Functions, not Static Files. Cold start latency on page load.

### Pitfall 5: APK Download Link 404
**What goes wrong:** Website "Download APK" button links to GitHub Releases URL that doesn't exist yet. Users get 404.
**Why it happens:** Website deployed before APK release is published on GitHub.
**How to avoid:** Use `/releases/latest` URL pattern (auto-redirects to latest release). Ensure at least one release exists before website goes live. Consider a fallback message if no release exists.
**Warning signs:** Clicking download button shows GitHub 404 page.

### Pitfall 6: Missing `lang="id"` and OG Locale
**What goes wrong:** Page is in Bahasa Indonesia but `<html lang="en">` and no `og:locale`. Search engines may not serve it correctly to Indonesian users.
**Why it happens:** Default Astro template uses `lang="en"`.
**How to avoid:** Set `<html lang="id">` in BaseLayout.astro. Add `<meta property="og:locale" content="id_ID" />`.
**Warning signs:** Google Search Console language mismatch warnings.

### Pitfall 7: Sharp Installation Fails on Windows
**What goes wrong:** `sharp` native binary compilation fails on Windows due to missing build tools.
**Why it happens:** `sharp` uses native Node.js addons that may need `node-gyp` + Visual C++ Build Tools on Windows.
**How to avoid:** Modern `sharp` (0.34.x) ships prebuilt binaries for Windows x64 — should work out of the box with Node.js 24.8.0. If it fails: `npm install -D sharp --ignore-scripts && npx node-gyp rebuild`.
**Warning signs:** `npm install` errors mentioning `node-gyp`, `msbuild`, or `sharp`.

## Code Examples

### Complete Feature Card Component

```astro
---
// src/components/Features.astro
const features = [
  {
    title: "Absensi NFC Otomatis",
    description: "Karyawan cukup tap kartu NFC di tablet — hadir langsung tercatat. Tanpa username, tanpa password.",
    icon: "nfc",
  },
  {
    title: "Jadwal Shift Cerdas",
    description: "Atur jadwal Pagi, Siang, Sore untuk semua karyawan dalam satu tampilan grid mingguan.",
    icon: "calendar",
  },
  {
    title: "Laporan Real-Time",
    description: "Pantau siapa yang sudah masuk, sedang break, atau sudah pulang — langsung dari dashboard admin.",
    icon: "chart",
  },
  {
    title: "Mode Kiosk 24/7",
    description: "Tablet berjalan non-stop sebagai kiosk absensi. Tidak perlu pengawasan, tidak perlu restart.",
    icon: "device",
  },
];
---

<section class="bg-brand-surface py-20 lg:py-28">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="text-center">
      <h2 class="text-3xl font-bold tracking-tight text-brand-text sm:text-4xl">
        Fitur Unggulan
      </h2>
      <p class="mt-4 text-lg text-brand-text-secondary">
        Semua yang dibutuhkan untuk mengelola kehadiran karyawan restoran.
      </p>
    </div>
    <div class="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-4">
      {features.map((feature) => (
        <div class="rounded-2xl bg-white p-8 shadow-sm ring-1 ring-brand-border
                    hover:shadow-md transition-shadow duration-200">
          <div class="mb-4 flex h-12 w-12 items-center justify-center rounded-xl
                      bg-brand-light text-brand-primary">
            <!-- Inline SVG icon based on feature.icon -->
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <!-- Icon paths vary per feature -->
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-brand-text">{feature.title}</h3>
          <p class="mt-2 text-sm leading-6 text-brand-text-secondary">
            {feature.description}
          </p>
        </div>
      ))}
    </div>
  </div>
</section>
```

### How It Works Section (3 Steps)

```astro
---
// src/components/HowItWorks.astro
const steps = [
  {
    number: "1",
    title: "Pasang Tablet",
    description: "Letakkan tablet Android di area masuk restoran. Buka ABSENKOK dalam mode kiosk.",
  },
  {
    number: "2",
    title: "Tap Kartu NFC",
    description: "Karyawan tap kartu NFC masing-masing ke tablet saat masuk dan pulang kerja.",
  },
  {
    number: "3",
    title: "Pantau & Kelola",
    description: "Admin lihat dashboard kehadiran real-time, atur jadwal shift, dan export laporan PDF.",
  },
];
---

<section class="bg-white py-20 lg:py-28">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="text-center">
      <h2 class="text-3xl font-bold tracking-tight text-brand-text sm:text-4xl">
        Cara Kerja
      </h2>
    </div>
    <div class="mt-16 grid grid-cols-1 gap-12 md:grid-cols-3">
      {steps.map((step) => (
        <div class="text-center">
          <div class="mx-auto flex h-16 w-16 items-center justify-center rounded-full
                      bg-brand-primary text-white text-2xl font-bold shadow-lg">
            {step.number}
          </div>
          <h3 class="mt-6 text-xl font-semibold text-brand-text">{step.title}</h3>
          <p class="mt-3 text-base leading-7 text-brand-text-secondary">
            {step.description}
          </p>
        </div>
      ))}
    </div>
  </div>
</section>
```

### Footer with Developer Credit

```astro
---
// src/components/Footer.astro
const currentYear = new Date().getFullYear();
---

<footer class="bg-gray-900 py-12">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="flex flex-col items-center gap-4">
      <p class="text-sm text-gray-400">
        &copy; {currentYear} ABSENKOK. Sistem Absensi NFC untuk Restoran.
      </p>
      <p class="text-xs text-gray-500">
        Dibuat oleh <span class="font-semibold text-gray-400">Akmal</span>
      </p>
    </div>
  </div>
</footer>
```

### CSS-Only Tablet Mockup Frame

```html
<!-- CSS-only tablet frame using Tailwind classes -->
<div class="relative mx-auto max-w-md lg:max-w-lg">
  <!-- Tablet body -->
  <div class="rounded-[2rem] bg-gray-900 p-3 shadow-2xl ring-1 ring-white/10">
    <!-- Screen bezel -->
    <div class="rounded-[1.5rem] overflow-hidden bg-white">
      <Image
        src={heroMockup}
        alt="ABSENKOK - tampilan aplikasi absensi NFC"
        class="w-full h-auto"
        width={600}
        quality={85}
      />
    </div>
  </div>
  <!-- Decorative gradient glow behind tablet -->
  <div class="absolute -inset-4 -z-10 rounded-[2.5rem] bg-gradient-to-br
              from-brand-primary/20 via-brand-accent/10 to-transparent blur-2xl" />
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@astrojs/tailwind` (v3) | `@tailwindcss/vite` (v4) | Tailwind v4 release (2025) | No JS config file. CSS-first `@theme {}` directives. Faster Rust-based engine. |
| `tailwind.config.js` | `@theme {}` in CSS | Tailwind v4 | All customization moves to CSS. Simpler mental model. |
| Astro `latest` = v5 | Astro `latest` = v6 | ~2026-03 | Must explicitly pin `astro@^5.18.0`. Scaffolding defaults to v6. |
| Google Fonts CDN | `@fontsource` self-hosted | Standard practice ~2024+ | Zero network requests, no FOUT, GDPR-friendly. |

**Deprecated/outdated:**
- `@astrojs/tailwind`: Only supports Tailwind v3. Do NOT use. Use `@tailwindcss/vite` for v4.
- `tailwind.config.js`: Legacy v3 pattern. Tailwind v4 uses CSS `@theme {}` directives.
- Astro `legacy` tag (v4): Two major versions behind. Don't use.

## Open Questions

1. **Exact GitHub Releases URL for APK download**
   - What we know: Button should link to GitHub Releases for the APK download
   - What's unclear: The actual GitHub repo URL (user/repo name) for the releases link
   - Recommendation: Use a placeholder URL like `https://github.com/user/absenkok/releases/latest` and update during implementation. The `/releases/latest` pattern auto-redirects to the newest release.

2. **Hero mockup image source**
   - What we know: Need a screenshot of the ABSENKOK app displayed in a tablet frame
   - What's unclear: Whether to capture a real screenshot from the running app or create a designed mockup
   - Recommendation: Take a real screenshot of the schedule grid or kiosk screen from the Flutter app, then wrap it in a CSS tablet frame (see Pattern above). More authentic than a designed mockup.

3. **Vercel project setup and domain**
   - What we know: Deploy to Vercel with URL like `absenkok.vercel.app`
   - What's unclear: Whether a custom domain will be used
   - Recommendation: Start with `absenkok.vercel.app` (free Vercel subdomain). Custom domain can be added later.

4. **OG image design**
   - What we know: Need a 1200x630 `og-image.png` for social sharing (WhatsApp, etc.)
   - What's unclear: Exact design — app screenshot vs branded graphic
   - Recommendation: Create a simple branded image: ABSENKOK logo + tagline + app screenshot thumbnail on a clean background. Can be a static PNG placed in `public/`.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Astro built-in check + build validation |
| Config file | `astro.config.mjs` (also serves as build config) |
| Quick run command | `npx astro check` |
| Full suite command | `npx astro check && npx astro build` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WEB-01 | Hero section with tablet mockup + tagline | smoke (build + inspect HTML) | `npx astro build && findstr /i "hero" dist\index.html` | ❌ Wave 0 |
| WEB-02 | Feature showcase 4-6 features with icons | smoke (build + inspect HTML) | `npx astro build && findstr /i "fitur" dist\index.html` | ❌ Wave 0 |
| WEB-03 | How It Works 3 steps | smoke (build + inspect HTML) | `npx astro build && findstr /i "cara-kerja" dist\index.html` | ❌ Wave 0 |
| WEB-04 | Download APK button → GitHub Releases | smoke (build + inspect HTML) | `npx astro build && findstr /i "github.com" dist\index.html` | ❌ Wave 0 |
| WEB-05 | Developer credit "Akmal" in footer | smoke (build + inspect HTML) | `npx astro build && findstr /i "Akmal" dist\index.html` | ❌ Wave 0 |
| WEB-06 | Responsive design | manual-only | Manual browser resize test (Chrome DevTools) | N/A |
| WEB-07 | All copy Bahasa Indonesia | smoke (build + inspect HTML) | `npx astro build && findstr /i "lang=\"id\"" dist\index.html` | ❌ Wave 0 |
| WEB-08 | Page load <2s, zero JS | smoke (check dist for JS) | `npx astro build && Get-ChildItem dist\_astro\*.js -ErrorAction SilentlyContinue` (should be empty) | ❌ Wave 0 |
| WEB-09 | SEO meta tags + sitemap.xml | smoke (check dist files) | `npx astro build && Test-Path dist\sitemap-index.xml` | ❌ Wave 0 |
| WEB-10 | Deploy to Vercel | manual-only | Manual Vercel deployment verification | N/A |

### Sampling Rate
- **Per task commit:** `npx astro check` (type checking, ~5s)
- **Per wave merge:** `npx astro check && npx astro build` (full build, ~15s)
- **Phase gate:** Full build green + manual browser check + Vercel deploy verified

### Wave 0 Gaps
- [ ] `astro.config.mjs` — project configuration (Tailwind, Vercel, Sitemap)
- [ ] `package.json` — all dependencies installed
- [ ] `src/styles/global.css` — Tailwind v4 CSS-first config with brand colors
- [ ] `tsconfig.json` — TypeScript config for Astro
- [ ] Framework install: `npm install` — entire project needs scaffolding from scratch

*(This is a greenfield project — ALL infrastructure is Wave 0)*

## Sources

### Primary (HIGH confidence)
- npm registry: `astro` dist-tags confirmed `latest: 6.0.4`, v5 range up to `5.18.1` — verified 2026-03-12
- npm registry: `@tailwindcss/vite@4.2.1`, `tailwindcss@4.2.1` — current versions verified
- npm registry: `@astrojs/vercel@9.0.5` peer dependency `astro ^5.0.0` — verified
- npm registry: `@astrojs/sitemap@3.7.1`, `sharp@0.34.5`, `@fontsource/inter@5.2.8`, `@astrojs/check@0.9.7` — verified
- Flutter `theme.dart`: All `AppColors` hex values extracted directly from source code

### Secondary (MEDIUM confidence)
- v3.0 research docs (`.planning/research/STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md`, `FEATURES.md`) — researched 2026-03-12, comprehensive stack and pattern analysis
- Astro 5 documentation patterns — validated against npm package capabilities

### Tertiary (LOW confidence)
- `npm create astro@latest` behavior with Astro 6 as default — inferred from dist-tags, not directly tested on this machine
- `sharp` Windows compatibility — historically works with prebuilt binaries on Node.js 20+, not tested on Node.js 24.8.0 specifically

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all npm versions verified, peer dependencies checked, compatibility confirmed
- Architecture: HIGH — Astro component patterns are well-established, project structure follows official conventions
- Pitfalls: HIGH — Astro 5 vs 6 issue verified via dist-tags, Tailwind v4 config differences documented in official migration guide
- Brand consistency: HIGH — all color values extracted directly from Flutter `theme.dart` source code

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (30 days — stable ecosystem, pinned versions)

# Phase 19: Website Polish — Real Screenshots, About/Architecture Section, Tech Icons - Research

**Researched:** 2026-03-13
**Domain:** Astro 5 image optimization, static site polish, component architecture
**Confidence:** HIGH

## Summary

Phase 19 polishes the existing ABSENKOK landing website (Astro 5.18.1 + Tailwind v4) by replacing the CSS tablet mockup with real app screenshots, adding a new About/Architecture section telling the project story, and including inline SVG tech icons. The website project lives at `C:\Users\HYPE R Series\Desktop\projekan\absenkok-website\` — a separate repo from the Flutter app.

The critical technical challenge is **image optimization**: the 5 PNG screenshots in `public/` total **17.14MB** (with one image at 9.81MB alone). These MUST be moved to `src/assets/images/` and served via Astro's built-in `<Image>` component, which auto-converts to WebP at build time using `sharp` (already installed). Testing confirms this produces a **98% size reduction** — from 17MB to ~253KB total.

The new About/Architecture section is a greenfield component following the existing pattern of `.astro` files with Tailwind classes, CSS animations, and inline SVG icons (no JS). Tech stack icons (Flutter, Supabase, NFC, Android) will be inline SVGs consistent with Decision #31.

**Primary recommendation:** Move all images to `src/assets/images/` with kebab-case filenames, use Astro `<Image>` component for automatic WebP conversion, create `About.astro` component inserted between HowItWorks and Download in `index.astro`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WEB-P01 | Hero section menggunakan gambar asli "enakko hero.png" (bukan CSS mockup) | Astro `<Image>` component imports from `src/assets/`, auto-optimizes to WebP. Replace 140-line CSS mockup with single `<Image>` tag. 2337×2928 PNG → 800w WebP = 53KB |
| WEB-P02 | Screenshot asli dari app dipakai di section Features atau HowItWorks | 4 additional screenshots available. Best fit: HowItWorks steps get screenshot companions (one per step). Astro Image handles all optimization |
| WEB-P03 | Section About/Architecture baru — tech stack, dev story, deployment | New `About.astro` component. Three content blocks: Tech Stack (Flutter + Supabase + NFC), Dev Story (solo + vibe coding + AI), Deployment (Android Kiosk). Follows existing design patterns |
| WEB-P04 | Icon SVG Supabase dan Flutter ditampilkan di section architecture | Inline SVGs consistent with Decision #31. Full SVG path data provided in this research |
</phase_requirements>

## Standard Stack

### Core (Already Installed — No New Dependencies)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| astro | 5.18.1 | Static site framework | ✅ Installed |
| tailwindcss | 4.2.1 | Utility-first CSS (v4 CSS-first) | ✅ Installed |
| sharp | 0.34.5 | Image optimization (Astro's Image component) | ✅ In devDependencies |
| @fontsource/inter | 5.2.8 | Self-hosted font | ✅ Installed |

### No New Dependencies Required
This phase uses only existing capabilities. Astro's built-in `<Image>` component + sharp handles all image optimization. SVG icons are inline (Decision #31 — no icon library).

## Architecture Patterns

### Current Project Structure
```
absenkok-website/
├── public/                    # Static files (served as-is, NO optimization)
│   ├── enakko hero.png        # 2337×2928, 2.13MB ← MUST MOVE
│   ├── gambar berhasil login.png  # 1469×2859, 2.08MB ← MUST MOVE
│   ├── moonitoing tangan.png  # 4081×3619, 9.81MB ← MUST MOVE
│   ├── pilih absen otmatis tangan.png  # 1871×953, 1.13MB ← MUST MOVE
│   ├── tangan bersama.png     # 2002×1339, 1.79MB ← MUST MOVE
│   └── favicon.svg            # Keep here
├── src/
│   ├── assets/images/         # Currently empty — target for optimized images
│   ├── components/
│   │   ├── Header.astro
│   │   ├── Hero.astro         # MODIFY: replace CSS mockup with real image
│   │   ├── Features.astro     # OPTIONAL: could add screenshots
│   │   ├── HowItWorks.astro   # MODIFY: add screenshot companions per step
│   │   ├── Download.astro
│   │   └── Footer.astro
│   ├── layouts/BaseLayout.astro
│   ├── pages/index.astro      # MODIFY: add About component import
│   └── styles/global.css      # Tailwind v4 @theme + @keyframes
└── astro.config.mjs           # output: 'static', Vercel adapter
```

### Target Structure After Phase 19
```
src/
├── assets/images/
│   ├── enakko-hero.png            # Renamed: kebab-case, no spaces
│   ├── login-success.png          # Renamed from "gambar berhasil login.png"
│   ├── monitoring-screen.png      # Renamed from "moonitoing tangan.png"
│   ├── attendance-selection.png   # Renamed from "pilih absen otmatis tangan.png"
│   └── team-hands.png             # Renamed from "tangan bersama.png"
├── components/
│   ├── Header.astro               # ADD: "Arsitektur" nav link
│   ├── Hero.astro                 # REPLACE: CSS mockup → <Image> of enakko-hero
│   ├── Features.astro             # No change needed
│   ├── HowItWorks.astro           # ADD: screenshot per step
│   ├── About.astro                # NEW: About/Architecture section
│   ├── Download.astro
│   └── Footer.astro
├── pages/index.astro              # ADD: <About /> between HowItWorks and Download
└── styles/global.css              # May add minor utility classes
```

### Pattern 1: Astro Image Optimization (LOCAL images)

**What:** Astro's `<Image>` component from `astro:assets` auto-optimizes images at build time using sharp.
**When to use:** ALL images that are part of the site content (not user-uploaded).
**Key facts (verified from Astro 5.18.1 source):**
- Default output format: **WebP** (`DEFAULT_OUTPUT_FORMAT = "webp"` in consts.js)
- Images MUST be in `src/` (e.g., `src/assets/images/`) — NOT `public/`
- Images in `public/` are served **as-is** with zero optimization
- Import returns `ImageMetadata` with `{ src, width, height, format }`
- Output goes to `_astro/` directory with content-hashed filenames
- `layout` prop options: `constrained`, `fixed`, `full-width`, `none` (default)

**Example:**
```astro
---
// In any .astro component
import { Image } from 'astro:assets';
import heroImage from '../assets/images/enakko-hero.png';
---

<Image
  src={heroImage}
  alt="ABSENKOK admin dashboard pada smartphone"
  width={800}
  class="rounded-2xl shadow-2xl"
/>
<!-- Outputs: <img src="/_astro/enakko-hero.DxF3k2a1.webp" width="800" height="1003" ... /> -->
```

### Pattern 2: Component Composition (Existing Pattern)
**What:** Each section is a standalone `.astro` component imported into `index.astro`.
**Example:**
```astro
---
// index.astro
import About from '../components/About.astro';
---
<HowItWorks />
<About />        <!-- NEW: inserted here -->
<Download />
```

### Pattern 3: Inline SVG Icons (Decision #31)
**What:** SVG icons are embedded directly in component markup, no icon library.
**Why:** Zero JavaScript, zero external requests. Consistent with existing feature cards.

### Anti-Patterns to Avoid
- **Serving images from `public/`:** Files in `public/` bypass Astro's optimization pipeline entirely. A 9.81MB PNG would be served as-is = death for page load time.
- **Using `<img>` tag directly:** Won't trigger Astro's sharp optimization. Always use `<Image>` from `astro:assets`.
- **Filenames with spaces in `src/assets/`:** While Astro can handle them via ESM imports, kebab-case names are cleaner for imports: `import img from '../assets/images/enakko-hero.png'` vs `import img from '../assets/images/enakko hero.png'`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image optimization | Manual sharp scripts, webpack loaders | Astro `<Image>` component | Built-in, zero config, auto WebP, content hashes, proper `<img>` attributes |
| Responsive images | Manual srcset generation | Astro `<Image>` with `widths` / `layout` prop | Handles srcset, sizes, format negotiation automatically |
| SVG sprite system | Icon sprite sheets, icon font | Inline SVG in component | Only 4-5 icons needed, no runtime overhead |
| CSS tablet frame | Complex CSS border/shadow mockup | Real `<img>` with `rounded-2xl shadow-2xl` | Real screenshot is more convincing and simpler code |

**Key insight:** The existing CSS tablet mockup in Hero.astro is 90 lines of divs simulating a grid UI. A single `<Image>` tag with Tailwind classes (`rounded-2xl shadow-2xl`) is superior in every way — visually, performance-wise, and maintainability.

## Common Pitfalls

### Pitfall 1: Images Stay in public/ (17MB payload)
**What goes wrong:** If images remain in `public/`, they're copied to `dist/` as-is. Total: 17.14MB of unoptimized PNGs. Page load > 10 seconds.
**Why it happens:** Easy to use `/enakko%20hero.png` in `<img>` tag and forget about optimization.
**How to avoid:** Move ALL content images to `src/assets/images/`. Use `<Image>` component exclusively. Delete originals from `public/` after moving.
**Warning signs:** Build output in `dist/` contains `.png` files > 100KB.

### Pitfall 2: Forgetting `alt` Text on Images
**What goes wrong:** Astro's `<Image>` component **throws an error** if `alt` is undefined or null (verified in Image.astro source: `throw new AstroError(AstroErrorData.ImageMissingAlt)`).
**How to avoid:** Always provide descriptive `alt` text in Bahasa Indonesia.

### Pitfall 3: Image Filename Spaces Breaking Imports
**What goes wrong:** Files with spaces in names require quoted imports and can cause issues in some build tools.
**How to avoid:** Rename all files to kebab-case when moving to `src/assets/images/`:
  - `enakko hero.png` → `enakko-hero.png`
  - `gambar berhasil login.png` → `login-success.png`
  - `moonitoing tangan.png` → `monitoring-screen.png`
  - `pilih absen otmatis tangan.png` → `attendance-selection.png`
  - `tangan bersama.png` → `team-hands.png`

### Pitfall 4: Oversized Hero Image Dimensions
**What goes wrong:** Using the full 2337×2928 resolution for a hero that displays at ~400px wide. Even as WebP, unnecessary resolution = wasted bytes.
**How to avoid:** Specify `width={800}` on hero image. Astro/sharp will resize proportionally. 800px width is generous for a phone-in-hand image in a two-column layout.

### Pitfall 5: Not Updating Header Navigation
**What goes wrong:** New About/Architecture section exists but isn't reachable via navigation. Users scroll past it.
**How to avoid:** Add `id="arsitektur"` to the About section and add nav link in Header.astro.

### Pitfall 6: Build May Be Slow With 9.81MB PNG
**What goes wrong:** `moonitoing tangan.png` at 4081×3619 / 9.81MB takes noticeably longer to process through sharp during build.
**How to avoid:** Not a blocker, just expect first build to take 10-20 seconds longer. Output WebP will be tiny (~97KB at 1200w).

## Code Examples

### Example 1: Hero Section with Real Image
```astro
---
// Hero.astro — Replace CSS mockup with real screenshot
import { Image } from 'astro:assets';
import heroImage from '../assets/images/enakko-hero.png';
---

<section class="relative bg-white py-20 lg:py-32 overflow-hidden">
  <!-- Decorative background shapes (keep existing) -->
  <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-brand-mint/40 rounded-full blur-[100px] -translate-y-1/2 translate-x-1/4"></div>
  <div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-brand-teal/20 rounded-full blur-[80px] translate-y-1/3 -translate-x-1/4"></div>

  <div class="relative max-w-7xl mx-auto px-6 lg:px-8">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 lg:items-center">

      <!-- Left Column: Text (keep existing) -->
      <div class="max-w-xl" style="animation: slide-in-left 0.8s ease-out both;">
        <!-- ... existing text content unchanged ... -->
      </div>

      <!-- Right Column: REAL IMAGE (replaces 90-line CSS mockup) -->
      <div class="relative flex justify-center lg:justify-end" style="animation: slide-in-right 0.8s ease-out 0.2s both;">
        <div class="absolute -inset-4 -z-10 rounded-[2.5rem] bg-gradient-to-br from-brand-teal/30 via-brand-mint/20 to-brand-pink/10 blur-2xl"></div>
        <div class="animate-float">
          <Image
            src={heroImage}
            alt="Tangan memegang smartphone menampilkan dashboard admin ABSENKOK"
            width={420}
            class="rounded-2xl shadow-2xl ring-1 ring-black/5"
          />
        </div>
      </div>

    </div>
  </div>
</section>
```

### Example 2: HowItWorks with Screenshot Companions
```astro
---
import { Image } from 'astro:assets';
import monitoringImg from '../assets/images/monitoring-screen.png';
import attendanceImg from '../assets/images/attendance-selection.png';
import loginImg from '../assets/images/login-success.png';

const steps = [
  {
    number: "1", title: "Pasang Tablet",
    description: "Letakkan tablet Android di area masuk restoran. Buka ABSENKOK dalam mode kiosk.",
    accent: "bg-brand-teal text-white",
    image: attendanceImg,
    imageAlt: "Layar pilihan absensi otomatis pada ABSENKOK",
  },
  // ... etc
];
---

<!-- Each step now includes a screenshot below the text -->
{steps.map((step, i) => (
  <div class="text-center group" style={`animation: fade-in-up 0.6s ease-out ${0.2 + i * 0.2}s both;`}>
    <div class={`h-16 w-16 rounded-full ${step.accent} ...`}>{step.number}</div>
    <h3 class="...">{step.title}</h3>
    <p class="...">{step.description}</p>
    {step.image && (
      <div class="mt-6">
        <Image
          src={step.image}
          alt={step.imageAlt}
          width={320}
          class="rounded-xl shadow-md mx-auto"
        />
      </div>
    )}
  </div>
))}
```

### Example 3: About/Architecture Section Structure
```astro
---
// About.astro — Project story + tech stack + deployment
import { Image } from 'astro:assets';
import teamImg from '../assets/images/team-hands.png';
---

<section id="arsitektur" class="bg-white py-20 lg:py-28">
  <div class="max-w-7xl mx-auto px-6 lg:px-8">
    <!-- Section header -->
    <div class="text-center max-w-2xl mx-auto mb-16">
      <h2 class="text-3xl font-bold tracking-tight text-brand-navy sm:text-4xl">
        Tentang ABSENKOK
      </h2>
      <p class="mt-4 text-lg leading-8 text-brand-text-secondary">
        Solo project, dibangun dengan vibe coding dan AI.
      </p>
    </div>

    <!-- Tech Stack Icons Row -->
    <div class="flex justify-center gap-8 mb-16">
      <!-- Flutter icon inline SVG -->
      <!-- Supabase icon inline SVG -->
      <!-- NFC icon inline SVG -->
      <!-- Android icon inline SVG -->
    </div>

    <!-- Three content cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      <!-- Card 1: Tech Stack -->
      <!-- Card 2: Dev Story -->
      <!-- Card 3: Deployment -->
    </div>
  </div>
</section>
```

### Example 4: Inline SVG Icons for Tech Stack

#### Flutter Logo SVG
```html
<!-- Flutter — Official geometric mark, blue (#027DFD) -->
<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 48 48">
  <path fill="#40C4FF" d="M26 4L6 24l6.4 6.4L34.4 8.4z"/>
  <path fill="#40C4FF" d="M26 4l-8.2 8.2 6.4 6.4L34.4 8.4z" opacity=".5"/>
  <path fill="#29B6F6" d="M26 36l-8-8 6.4-6.4L36.8 34z"/>
  <path fill="#01579B" d="M18 28l4-4 4 4-4 4z"/>
  <path fill="#0288D1" d="M26 36l-4-4 4-4 4 4z"/>
</svg>
```

**Simpler Flutter icon alternative (single-path, suitable for small sizes):**
```html
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none">
  <path d="M14.314 0L3.098 11.216l3.47 3.47L17.784 3.47M14.314 11.216l-5.648 5.648 3.47 3.47 9.177-9.118-3.47-3.47-3.529 3.47" fill="#54C5F8"/>
  <path d="M8.666 16.864l3.47 3.47 3.47-3.47-3.47-3.47" fill="#01579B"/>
</svg>
```

#### Supabase Logo SVG
```html
<!-- Supabase — Official logo mark, green (#3ECF8E) -->
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 109 113" fill="none">
  <path d="M63.708 110.284c-2.86 3.601-8.658 1.628-8.727-2.97l-1.007-67.251h45.22c8.19 0 12.758 9.46 7.665 15.874L63.708 110.284z" fill="url(#supabase-a)"/>
  <path d="M63.708 110.284c-2.86 3.601-8.658 1.628-8.727-2.97l-1.007-67.251h45.22c8.19 0 12.758 9.46 7.665 15.874L63.708 110.284z" fill="url(#supabase-b)" fill-opacity=".2"/>
  <path d="M45.317 2.071c2.86-3.601 8.657-1.628 8.726 2.97l.442 67.251H9.83c-8.19 0-12.759-9.46-7.665-15.875L45.317 2.072z" fill="#3ECF8E"/>
  <defs>
    <linearGradient id="supabase-a" x1="53.974" y1="54.974" x2="94.163" y2="71.829" gradientUnits="userSpaceOnUse">
      <stop stop-color="#249361"/>
      <stop offset="1" stop-color="#3ECF8E"/>
    </linearGradient>
    <linearGradient id="supabase-b" x1="36.156" y1="30.578" x2="54.484" y2="65.081" gradientUnits="userSpaceOnUse">
      <stop/>
      <stop offset="1" stop-opacity="0"/>
    </linearGradient>
  </defs>
</svg>
```

#### NFC Icon SVG (already used in Features.astro)
```html
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M6 8.32a7.43 7.43 0 0 1 0 7.36"/>
  <path d="M9.46 6.21a11.76 11.76 0 0 1 0 11.58"/>
  <path d="M12.91 4.1a16.07 16.07 0 0 1 0 15.8"/>
  <path d="M16.37 2a20.4 20.4 0 0 1 0 20"/>
</svg>
```

#### Android Icon SVG
```html
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="5" y="11" width="14" height="10" rx="2"/>
  <path d="M12 2C8.69 2 6 4.69 6 8v3h12V8c0-3.31-2.69-6-6-6z"/>
  <circle cx="9" cy="7" r="1" fill="currentColor"/>
  <circle cx="15" cy="7" r="1" fill="currentColor"/>
  <line x1="7" y1="2" x2="9" y2="5"/>
  <line x1="17" y1="2" x2="15" y2="5"/>
</svg>
```

#### AI/Vibe Coding Icon (sparkle/brain)
```html
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 3l1.912 5.813a2 2 0 0 0 1.275 1.275L21 12l-5.813 1.912a2 2 0 0 0-1.275 1.275L12 21l-1.912-5.813a2 2 0 0 0-1.275-1.275L3 12l5.813-1.912a2 2 0 0 0 1.275-1.275L12 3z"/>
</svg>
```

## Image Optimization Data

### Verified Size Reduction (tested with sharp 0.34.5)

| Image | Original | Dimensions | Target Width | WebP Size | Reduction |
|-------|----------|------------|-------------|-----------|-----------|
| enakko hero.png | 2.13MB | 2337×2928 | 800px | 53KB | 98% |
| gambar berhasil login.png | 2.08MB | 1469×2859 | 600px | 41KB | 98% |
| moonitoing tangan.png | 9.81MB | 4081×3619 | 1200px | 97KB | 99% |
| pilih absen otmatis tangan.png | 1.13MB | 1871×953 | 800px | 28KB | 98% |
| tangan bersama.png | 1.79MB | 2002×1339 | 800px | 34KB | 98% |
| **TOTAL** | **17.14MB** | — | — | **253KB** | **98.5%** |

### Recommended Image Usage Map

| Image (renamed) | Used In | Purpose | Width |
|-----------------|---------|---------|-------|
| `enakko-hero.png` | Hero.astro | Hero image — hand holding phone with admin dashboard | 420-600px |
| `login-success.png` | HowItWorks.astro | Step 2 or 3 companion — login success confirmation | 320px |
| `monitoring-screen.png` | HowItWorks.astro | Step 3 companion — real-time monitoring dashboard | 400-600px |
| `attendance-selection.png` | HowItWorks.astro | Step 1 or 2 companion — attendance mode selection | 320-400px |
| `team-hands.png` | About.astro | About section illustration or decorative | 600px |

## About/Architecture Section Content

### Content Structure (from user input)

**Section title:** "Tentang ABSENKOK" or "Arsitektur & Cerita"

**Three content blocks:**

1. **Tech Stack** — Flutter (mobile framework), Supabase (backend-as-a-service, free tier — pauses after 1 week inactivity), NFC (e-KTP, e-Toll, Flazz compatible)

2. **Development Story** — Solo project by Akmal. "Skill it and vibe coding" with Anthropic Sonnet 4.6 + Gemini Pro 3. Built iteratively with AI assistance.

3. **Deployment** — Android Kiosk mode (tablet runs 24/7 at restaurant entrance). No server management needed — Supabase handles everything.

### Visual Layout Options

**Recommended: Icon row + 3-column cards** (matches existing design language)
- Top: row of tech icons (Flutter, Supabase, NFC, Android) with labels
- Below: 3 cards similar to Features section cards
- Background: alternate color (bg-brand-surface or bg-white depending on adjacent sections)

Since HowItWorks uses `bg-white` and Download uses `bg-brand-navy`, the About section (between them) should use `bg-brand-surface` for visual rhythm.

## Section Order in index.astro

Current:
```
Header → Hero → Features → HowItWorks → Download → Footer
```

After Phase 19:
```
Header → Hero → Features → HowItWorks → About → Download → Footer
```

Navigation links:
```
Fitur | Cara Kerja | Arsitektur | Download
```

## State of the Art

| Old Approach (Phase 18) | Phase 19 Approach | Impact |
|--------------------------|-------------------|--------|
| CSS-drawn tablet mockup (90 lines of divs) | Real `<Image>` of app (~3 lines) | Authentic, convincing, maintainable |
| No images on page | 5 optimized WebP images via Astro Image | Visual richness + fast load |
| 4 sections (Hero, Features, HowItWorks, Download) | 5 sections (+ About/Architecture) | Complete story telling |
| Generic feature icons only | Tech stack brand icons (Flutter, Supabase) | Developer credibility |
| Images in `public/` (17MB, unused) | Images in `src/assets/` (253KB WebP output) | 98.5% size reduction |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Astro built-in build check |
| Config file | astro.config.mjs |
| Quick run command | `cd absenkok-website && npm run build` |
| Full suite command | `cd absenkok-website && npm run check && npm run build` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WEB-P01 | Hero uses real image, not CSS mockup | build + visual | `npm run build` (fails if import broken) | N/A — build test |
| WEB-P02 | Screenshots in HowItWorks | build + visual | `npm run build` (fails if import broken) | N/A — build test |
| WEB-P03 | About/Architecture section exists | build + visual | `npm run build && grep -i "arsitektur" dist/index.html` | N/A — build test |
| WEB-P04 | SVG icons render | build + visual | `npm run build && grep -i "supabase" dist/index.html` | N/A — build test |

### Sampling Rate
- **Per task commit:** `npm run build` — verifies all image imports resolve and HTML generates
- **Per wave merge:** `npm run check && npm run build` — TypeScript + build
- **Phase gate:** Build succeeds + visual inspection of `dist/index.html` + check no PNG files > 100KB in dist

### Wave 0 Gaps
None — existing build infrastructure covers all phase requirements. The `npm run build` command validates image imports, component syntax, and generates static output.

## Open Questions

1. **Hero image cropping/framing**
   - What we know: `enakko hero.png` (2337×2928) shows a hand holding a phone with the admin dashboard
   - What's unclear: Whether the image needs a decorative frame/border or should be shown as-is with just rounded corners + shadow
   - Recommendation: Start with `rounded-2xl shadow-2xl` and the existing gradient glow backdrop. Adjust if visual review shows it needs more framing.

2. **Which screenshots map to which HowItWorks steps**
   - What we know: 3 steps (Pasang Tablet, Tap Kartu NFC, Pantau & Kelola), 4 available screenshots
   - Recommendation: Step 1 → `attendance-selection.png`, Step 2 → `login-success.png`, Step 3 → `monitoring-screen.png`. Use `team-hands.png` in About section.

3. **About section wording — exact Bahasa Indonesia copy**
   - What we know: User provided key phrases ("skill it and vibe coding", "Anthropic Sonnet 4.6 + Gemini Pro 3")
   - Recommendation: Implementer writes copy matching existing tone (professional but casual, matching Footer's "Dibuat oleh Akmal" style)

## Sources

### Primary (HIGH confidence)
- **Astro 5.18.1 source code** — `node_modules/astro/components/Image.astro`, `dist/assets/consts.js`, `dist/assets/types.d.ts` — Image component API, default WebP format, layout options
- **sharp 0.34.5** — Tested WebP conversion on actual project images, verified 98% reduction
- **Existing website codebase** — All 6 components read and analyzed in detail

### Secondary (MEDIUM confidence)
- **SVG icon paths** — Flutter and Supabase logos sourced from common developer icon sets. Visual accuracy should be verified during implementation. Implementer can simplify paths if needed.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — No new dependencies, using only existing Astro + sharp capabilities
- Architecture: HIGH — Follows exact patterns already established in Phase 18 (component composition, inline SVGs, Tailwind classes)
- Image optimization: HIGH — Verified with actual sharp conversion on real project images
- Pitfalls: HIGH — Based on direct analysis of codebase + Astro source code
- SVG icons: MEDIUM — Logo paths may need visual tuning but structure is correct

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable — no dependency changes expected)

# Research Summary: v3.0 Schedule Grid + Landing Website

**Domain:** NFC attendance kiosk (Flutter/Android) + Marketing website (Astro.js)
**Researched:** 2026-03-12
**Overall confidence:** HIGH

## Executive Summary

The v3.0 milestone spans two completely independent deliverables: a Flutter schedule grid UI redesign within the existing app, and a brand-new Astro.js marketing landing website in a separate repository. Research confirms both are low-risk, well-bounded efforts.

For the **Schedule Grid Redesign**, the existing `shift_scheduler_screen.dart` (1,123 lines) already implements a functional week-view grid with employees on rows, Mon-Sun on columns, tap-to-assign, bulk assign, auto-generate, and PDF export. The redesign is primarily a **visual and UX overhaul**, not a fundamental architecture change. The one meaningful technology addition is `two_dimensional_scrollables` (official Flutter team package) which replaces 40+ lines of fragile manual scroll synchronization with a proper `TableView` widget featuring pinned headers and columns. All animation needs are covered by built-in Flutter primitives.

For the **Astro.js Landing Website**, the stack is straightforward: Astro 5 (not 6 — too new), Tailwind CSS v4 via the Vite plugin, Vercel deployment, and zero JavaScript shipped to the browser. The website is a single-page marketing site with ~5 sections, no dynamic content, no CMS, and no backend connection. The only integration with the Flutter app is a download link to GitHub Releases and shared brand colors.

The two workstreams have zero code dependencies on each other and can be developed in parallel. The schedule grid redesign touches an existing 1,123-line file that needs careful refactoring, while the website is a greenfield project in a separate directory.

## Key Findings

**Stack:** Flutter adds only `two_dimensional_scrollables ^0.3.8`. Website: Astro 5 + Tailwind v4 + Vercel. Minimal dependency surface.
**Architecture:** Schedule grid refactors from dual-ListView manual sync to `TableView` with pinned rows/columns. Website is pure static Astro components.
**Critical pitfall:** The schedule grid redesign must preserve all existing data flow (Supabase ↔ SQLite sync, bulk assign, auto-generate, PDF export) while replacing the rendering layer.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Phase 1: Schedule Grid UI Redesign (Flutter)** — Refactor `shift_scheduler_screen.dart` to use `TableView` from `two_dimensional_scrollables`, new cell design, animations
   - Addresses: Week-view grid, tap-to-assign cells, better visual design
   - Avoids: Preserves existing data layer untouched (Supabase sync, SQLite cache)
   - Risk: Medium — refactoring a 1,123-line stateful widget

2. **Phase 2: Astro.js Landing Website** — New project, scaffold → sections → deploy
   - Addresses: Marketing presence, APK download, feature showcase, developer watermark
   - Avoids: No backend coupling, no CMS complexity
   - Risk: Low — greenfield static site with well-known tools

**Phase ordering rationale:**
- Schedule grid first because it touches the existing codebase (risk mitigation — get the hard part done first)
- Website second because it's a greenfield project with no dependencies on the grid work
- Both can technically run in parallel since they're in separate repos

**Research flags for phases:**
- Phase 1: Standard patterns, but needs careful refactoring (1,123 lines). Test grid parity with existing features before committing.
- Phase 2: Standard patterns, unlikely to need additional research. Astro + Tailwind is well-documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Flutter) | HIGH | `two_dimensional_scrollables` verified compatible, official Flutter team package |
| Stack (Astro) | HIGH | All versions verified via npm registry, peer deps checked |
| Features | HIGH | Both feature sets are clearly scoped in PROJECT.md |
| Architecture | HIGH | Grid redesign is a rendering-layer swap. Website is standard Astro. |
| Pitfalls | MEDIUM | Scroll sync migration needs careful testing. Astro 5 vs 6 decision is timing-dependent. |

## Gaps to Address

- `two_dimensional_scrollables` `TableView` API specifics (exact `cellBuilder` patterns for interactive cells with tap handlers) — verify during phase-specific implementation
- Tailwind v4 `@theme` directive for custom brand colors — verify exact syntax in Astro context during website scaffolding
- Whether `npm create astro@latest` pulls Astro 6 by default (may need `npm create astro@5` syntax) — verify at project init time

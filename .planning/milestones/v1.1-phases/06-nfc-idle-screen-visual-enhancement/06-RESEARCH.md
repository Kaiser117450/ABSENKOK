# Phase 6: NFC Idle Screen Visual Enhancement - Research

**Researched:** 2026-03-02
**Domain:** Flutter CustomPainter animations, asset management, typography
**Confidence:** HIGH

## Summary

This phase transforms the kiosk idle screen from a functional white-background screen into a premium-feeling kiosk product. The current `kiosk_idle_screen.dart` (~1000 lines) uses a white `Scaffold` background with a simple pulse animation on the NFC ring. The enhancement involves: (1) a 3-layer ambient background animation using `CustomPainter`, (2) replacing the placeholder restaurant icon with the actual brand logo, (3) polishing the NFC ring with gradient and glow effects, and (4) improving the typography hierarchy.

All techniques required are core Flutter SDK capabilities -- no additional packages are needed. The project already uses `TickerProviderStateMixin` in the idle screen (for pulse and fade animations), `AppColors` brand palette in `theme.dart`, and `google_fonts` for Plus Jakarta Sans typography. The kiosk runs 24/7, so animation efficiency and memory stability are critical constraints.

**Primary recommendation:** Use `CustomPainter` with `AnimationController.repeat()` for all background layers, keep paint objects cached as class fields, and verify no jank after extended runtime by testing on real device for 30+ minutes.

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | >=3.3.0 | CustomPainter, AnimationController, Canvas API | Built-in, GPU-accelerated |
| google_fonts | ^6.2.1 | Plus Jakarta Sans (existing app font) | Already in pubspec.yaml |

### Supporting (already in project)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_riverpod | ^2.6.1 | State management (existing) | Already wired in idle screen |

### No New Dependencies Required
This phase uses only Flutter SDK primitives. No new packages needed.

## Architecture Patterns

### Current File Structure (Affected Files)
```
lib/
  screens/kiosk/
    kiosk_idle_screen.dart    # Main file to modify (~1000 lines)
  core/
    theme.dart                # AppColors - add dark kiosk palette
    constants.dart            # Animation timing constants
assets/
  images/
    logo_enakko.png           # NEW - brand logo asset
pubspec.yaml                  # Add asset path
```

### Pattern 1: Multi-Layer CustomPainter Background
**What:** Extract background animation into a dedicated `_AmbientBackgroundPainter` that receives animation values and paints 3 layers on a single Canvas.
**When to use:** Whenever you need smooth, non-interactive background effects that must run for hours without leaking.
**Key principle:** One CustomPainter, multiple layers -- NOT multiple overlapping Widgets with their own painters.

```dart
class _AmbientBackgroundPainter extends CustomPainter {
  final double gradientPhase;    // 0.0-1.0, from 20s controller
  final double breathePhase;     // 0.0-1.0, from 8s controller
  final double shimmerPhase;     // 0.0-1.0, from 15s controller

  // Cache Paint objects as fields -- never allocate in paint()
  final Paint _gradientPaint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _shimmerPaint = Paint();

  _AmbientBackgroundPainter({
    required this.gradientPhase,
    required this.breathePhase,
    required this.shimmerPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBaseGradient(canvas, size);
    _paintRadialGlow(canvas, size);
    _paintShimmerSweep(canvas, size);
  }

  @override
  bool shouldRepaint(_AmbientBackgroundPainter old) =>
      old.gradientPhase != gradientPhase ||
      old.breathePhase != breathePhase ||
      old.shimmerPhase != shimmerPhase;
}
```

### Pattern 2: Multiple AnimationControllers with Staggered Durations
**What:** Use separate `AnimationController` instances for each animation layer, each with its own duration and repeat behavior.
**When to use:** When animation layers have independent timing cycles (20s, 8s, 15s).

```dart
// In State class with TickerProviderStateMixin (already used)
late final AnimationController _bgGradientCtrl;
late final AnimationController _breatheCtrl;
late final AnimationController _shimmerCtrl;

@override
void initState() {
  super.initState();
  _bgGradientCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 20),
  )..repeat();
  _breatheCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 8),
  )..repeat(reverse: true);  // reverse for breathing effect
  _shimmerCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 15),
  )..repeat();
}

@override
void dispose() {
  _bgGradientCtrl.dispose();
  _breatheCtrl.dispose();
  _shimmerCtrl.dispose();
  // ... existing disposes
  super.dispose();
}
```

### Pattern 3: Dark Kiosk Background Theme
**What:** The idle screen currently uses white background. For premium kiosk feel, switch to dark background with warm/neutral dark tones. Keep existing `AppColors` for admin screens.
**When to use:** Only on the kiosk idle screen -- NOT app-wide.

```dart
// Add to AppColors in theme.dart
// Kiosk dark palette (only for idle screen background)
static const Color kioskDarkBase = Color(0xFF0F0F14);       // Near-black with slight warmth
static const Color kioskDarkWarm = Color(0xFF1A1410);        // Warm dark (subtle amber)
static const Color kioskDarkNeutral = Color(0xFF121218);     // Neutral dark (cool)
static const Color kioskGlowCenter = Color(0xFFDC2626);      // Brand red for center glow
static const Color kioskGlowCenterSoft = Color(0x4DDC2626);  // 30% opacity brand red
```

### Pattern 4: Asset Registration and Logo Placement
**What:** Add `assets/images/logo_enakko.png` to `pubspec.yaml` and use `Image.asset()` in the header.

```yaml
# pubspec.yaml addition
flutter:
  assets:
    - .env
    - assets/icon.png
    - assets/images/           # Add image directory
```

```dart
// In _buildHeader, replace the Container+Icon with:
Image.asset(
  'assets/images/logo_enakko.png',
  width: 120,
  height: 48,
  fit: BoxFit.contain,
)
```

### Anti-Patterns to Avoid
- **Multiple overlapping AnimatedContainer/AnimatedOpacity widgets for background:** Creates unnecessary widget rebuilds. Use a single `CustomPaint` widget instead.
- **Allocating Paint/Gradient objects inside `paint()` method:** Causes GC pressure on every frame. Cache as class fields and update only when values change.
- **Using `setState()` to drive animations:** Use `AnimationController` + `CustomPainter` which triggers repaint via `Listenable` without rebuilding the widget tree.
- **Particles or complex physics simulations:** Explicitly excluded by requirements -- too CPU-heavy for 24/7 kiosk.
- **`Timer.periodic` for animation:** Use `AnimationController` which ties to the `Ticker` and pauses when the widget is off-screen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gradient animation | Manual color interpolation with timers | `AnimationController` + `ColorTween` or manual lerp in `CustomPainter.paint()` | AnimationController handles vsync, dispose, lifecycle |
| Breathing scale effect | `Timer.periodic` + `setState` | `AnimationController..repeat(reverse: true)` with `CurvedAnimation(curve: Curves.easeInOut)` | Smoother, automatic reverse, proper disposal |
| Shimmer sweep | Stack of animated containers | Single diagonal `LinearGradient` with animated `transform` in CustomPainter | One paint call, no extra widgets |
| Gradient ring | Multiple Container borders | `CustomPainter` with `SweepGradient` stroke | Proper gradient along the circle path |

## Common Pitfalls

### Pitfall 1: Memory Leak from Undisposed AnimationControllers
**What goes wrong:** Adding new AnimationControllers without disposing them causes memory leaks, critical for 24/7 kiosk.
**Why it happens:** Easy to add controllers in `initState` and forget `dispose()`.
**How to avoid:** Add dispose for EVERY new controller. The existing code already disposes `_pulseController` and `_fadeController` -- follow the same pattern.
**Warning signs:** Increasing memory usage over hours in Flutter DevTools.

### Pitfall 2: Jank from Widget Rebuilds During Animation
**What goes wrong:** Using `AnimatedBuilder` wrapping the entire screen causes full widget tree rebuilds every frame.
**Why it happens:** `AnimatedBuilder` rebuilds its subtree on every animation tick.
**How to avoid:** Place `CustomPaint` at the BOTTOM of the Stack (behind all content). Only the `CustomPaint` widget repaints; the rest of the widget tree is untouched.
**Warning signs:** Choppy animation, >16ms frame times in performance overlay.

### Pitfall 3: White Flash on Dark Background Transition
**What goes wrong:** Changing `Scaffold.backgroundColor` from white to dark causes visible flash during navigation.
**Why it happens:** The idle screen is navigated to via GoRouter; if the background differs from the app theme.
**How to avoid:** Set `backgroundColor` on the Scaffold directly (not via theme). Current code already does `backgroundColor: Colors.white` -- just change to dark color.

### Pitfall 4: Logo Asset Not Found at Runtime
**What goes wrong:** App crashes or shows error widget if `assets/images/logo_enakko.png` is not properly registered.
**Why it happens:** Forgetting to add the asset path in `pubspec.yaml`, or incorrect path.
**How to avoid:** Add both the specific file AND the directory to the assets list. Run `flutter clean && flutter pub get` after pubspec changes. Use `errorBuilder` on `Image.asset()` as fallback.

### Pitfall 5: Dark Background Breaks Existing UI Elements
**What goes wrong:** Text, icons, and header elements currently use dark colors that become invisible on dark background.
**Why it happens:** The idle screen uses `AppColors.textPrimary` (dark) for text.
**How to avoid:** When switching to dark background, update ALL text colors in the idle screen to light variants. The header, clock, NFC text, and bottom bar all need color adjustments.

### Pitfall 6: withOpacity() Creates New Color Objects Every Build
**What goes wrong:** Using `color.withOpacity(0.3)` in `build()` creates a new Color object each frame.
**Why it happens:** `withOpacity()` returns a new instance.
**How to avoid:** Define opacity-variant colors as `static const` in AppColors, or cache them as class fields.

## Code Examples

### Complete Background Painter Structure
```dart
// Source: Flutter SDK CustomPainter documentation
class _AmbientBackgroundPainter extends CustomPainter {
  final double gradientPhase;
  final double breathePhase;
  final double shimmerPhase;

  _AmbientBackgroundPainter({
    required this.gradientPhase,
    required this.breathePhase,
    required this.shimmerPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1: Slow-shifting base gradient
    final rect = Offset.zero & size;
    // Lerp between warm-dark and neutral-dark based on phase
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(const Color(0xFF1A1410), const Color(0xFF121218), gradientPhase)!,
        Color.lerp(const Color(0xFF121218), const Color(0xFF0F0F14), gradientPhase)!,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Layer 2: Breathing radial glow at center
    final centerX = size.width / 2;
    final centerY = size.height * 0.55; // slightly below center for NFC zone
    final scale = 0.8 + (0.3 * breathePhase); // 0.8 -> 1.1
    final opacity = 0.3 + (0.3 * breathePhase); // 0.3 -> 0.6
    final glowRadius = size.width * 0.4 * scale;
    final glowGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFFDC2626).withOpacity(opacity * 0.15),
        const Color(0xFFDC2626).withOpacity(0.0),
      ],
    );
    final glowRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: glowRadius,
    );
    canvas.drawOval(
      glowRect,
      Paint()..shader = glowGradient.createShader(glowRect),
    );

    // Layer 3: Diagonal shimmer sweep
    final shimmerX = -size.width * 0.3 + (size.width * 1.6 * shimmerPhase);
    final shimmerGradient = LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white.withOpacity(0.02),
        Colors.white.withOpacity(0.04),
        Colors.white.withOpacity(0.02),
        Colors.transparent,
      ],
    );
    final shimmerRect = Rect.fromLTWH(shimmerX, 0, size.width * 0.3, size.height);
    canvas.save();
    canvas.rotate(0.3); // slight diagonal
    canvas.drawRect(shimmerRect, Paint()..shader = shimmerGradient.createShader(shimmerRect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AmbientBackgroundPainter old) =>
      gradientPhase != old.gradientPhase ||
      breathePhase != old.breathePhase ||
      shimmerPhase != old.shimmerPhase;
}
```

### Gradient NFC Ring with SweepGradient
```dart
// Source: Flutter CustomPainter docs
class _GradientRingPainter extends CustomPainter {
  final double glowOpacity; // for detected state inner glow

  _GradientRingPainter({this.glowOpacity = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Gradient ring stroke
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFDC2626), // brand red
          Color(0xFFF87171), // lighter red
          Color(0xFFFCA5A5), // even lighter
          Color(0xFFDC2626), // back to brand
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ringPaint);

    // Inner glow (when NFC detected)
    if (glowOpacity > 0) {
      final glowPaint = Paint()
        ..color = const Color(0xFFDC2626).withOpacity(glowOpacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, radius - 8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.glowOpacity != glowOpacity;
}
```

### Widget Integration in build()
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.kioskDarkBase, // Dark background
    body: Stack(
      children: [
        // Layer 0: Animated background (repaints independently)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_bgGradientCtrl, _breatheCtrl, _shimmerCtrl]),
            builder: (context, _) => CustomPaint(
              painter: _AmbientBackgroundPainter(
                gradientPhase: _bgGradientCtrl.value,
                breathePhase: _breatheCtrl.value,
                shimmerPhase: _shimmerCtrl.value,
              ),
            ),
          ),
        ),
        // Layer 1: Existing UI content (does NOT rebuild on animation tick)
        FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(session?.outletName, pendingCount),
                // ... rest of existing UI
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Typography Updates for Dark Background
```dart
// "Tempelkan Kartu NFC" - larger, lighter weight on dark bg
const Text(
  'Tempelkan Kartu NFC',
  style: TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w300,  // light weight for premium feel
    color: Colors.white,
    letterSpacing: 0.5,
  ),
),

// Outlet name - brand color accent
Text(
  outletName ?? '',
  style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,  // Red accent
    letterSpacing: 0.3,
  ),
),

// Time display - monospace, large
Text(
  timeString,
  style: GoogleFonts.jetBrainsMono(  // or robotoMono
    fontSize: 48,
    fontWeight: FontWeight.w300,
    color: Colors.white,
    letterSpacing: 2.0,
  ),
),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Container` with `AnimatedContainer` for gradients | `CustomPainter` for complex animations | Flutter 2.0+ | Much better perf, no widget rebuild |
| `Timer.periodic` for animation | `AnimationController` with `TickerProvider` | Always preferred | Proper lifecycle, vsync, auto-pause |
| `color.withOpacity()` | Pre-defined color constants or `Color.fromARGB` | Flutter 3.x guidance | Avoids per-frame allocations |
| `AnimatedBuilder` (deprecated name) | `AnimatedBuilder` is still valid | Current | Same API, just clarified docs |

## Open Questions

1. **Logo asset availability**
   - What we know: `assets/images/logo_enakko.png` is referenced in requirements but the `assets/images/` directory does not exist yet. Only `assets/icon.png` exists.
   - What's unclear: Does the user have the logo file ready? What format/resolution?
   - Recommendation: Plan should include a task to create the directory and add a placeholder instruction for the user to provide the file. Use `icon.png` as fallback with `errorBuilder`.

2. **Monospace font for time display**
   - What we know: Project uses `google_fonts` with Plus Jakarta Sans. Monospace fonts like JetBrains Mono or Roboto Mono are available via `google_fonts`.
   - What's unclear: Whether the user prefers a specific monospace font.
   - Recommendation: Use `GoogleFonts.robotoMono()` -- widely available, clean look, good for time display.

3. **Dark vs light idle screen approach**
   - What we know: Requirements specify "warm dark -> neutral dark" gradient, clearly indicating dark background. Current screen is white.
   - What's unclear: Whether header/bottom-bar should also go dark or stay light.
   - Recommendation: Full dark treatment for the entire idle screen for visual cohesion. All text/icons must be updated to light variants.

## Sources

### Primary (HIGH confidence)
- Flutter SDK `CustomPainter` API -- core framework, well-documented
- Flutter SDK `AnimationController` API -- core framework
- Project source: `lib/screens/kiosk/kiosk_idle_screen.dart` -- current implementation analyzed
- Project source: `lib/core/theme.dart` -- existing brand colors and font setup
- Project source: `pubspec.yaml` -- existing dependencies confirmed

### Secondary (MEDIUM confidence)
- Flutter performance best practices for CustomPainter (official Flutter docs)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - uses only Flutter SDK primitives already in the project
- Architecture: HIGH - CustomPainter + AnimationController is the standard Flutter approach for this type of visual work
- Pitfalls: HIGH - based on real patterns observed in the existing codebase (existing dispose patterns, existing animation patterns)

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable Flutter SDK patterns, unlikely to change)

# Phase 7: Admin UI System Polish - Research

**Researched:** 2026-03-02
**Domain:** Flutter UI component library, shimmer loading, toast notifications, design consistency
**Confidence:** HIGH

## Summary

Phase 7 is a pure UI polish phase creating reusable widget primitives (`AppCard`, `ShimmerSkeleton`, `AppEmptyState`, `AppBadge`) and applying them consistently across all admin screens. The project already has a well-defined theme system (`lib/core/theme.dart` with `AppColors` + `buildAppTheme()`) and uses `google_fonts` (Plus Jakarta Sans). The `toastification` package (v2.3.0) is already in `pubspec.yaml` and wrapped at app root (`ToastificationWrapper` in `app.dart`), but currently only used in kiosk screens -- admin screens still use raw `ScaffoldMessenger.showSnackBar`.

The codebase has no `lib/widgets/` directory yet. Each admin screen builds its own card containers with inline `BoxDecoration`. There are ~43 SnackBar usages across admin files and ~16 `CircularProgressIndicator` loading states in the dashboard alone. The main work is: (1) create a small widget library, (2) systematically replace inline card/loading/empty/toast patterns, (3) polish the bottom nav active indicator.

**Primary recommendation:** Create `lib/widgets/` with 4 focused widget files. Build shimmer with pure Flutter (no external package needed -- `LinearGradient` + `AnimationController` is lightweight and avoids adding dependencies). Replace SnackBar calls with a centralized `AppToast.show()` helper wrapping `toastification`.

## Standard Stack

### Core (Already in pubspec.yaml)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| toastification | ^2.3.0 | Toast notifications | Already installed, wrapped at app root, proven in kiosk screens |
| google_fonts | ^6.2.1 | Plus Jakarta Sans typography | Already the project font, used in theme.dart |

### Supporting (No new packages needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flutter Material | built-in | Shimmer via LinearGradient + AnimationController | Loading skeletons |
| Flutter Material | built-in | Card/Container/BoxDecoration | Consistent card widget |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom shimmer | `shimmer` package (^3.0.0) | Adds dependency for ~30 lines of code; custom is simpler and already proven in Phase 6 kiosk background |
| toastification | `fluttertoast` or `another_fluttertoast` | toastification already installed and configured -- no reason to switch |

**Installation:**
```bash
# No new packages needed -- everything is already in pubspec.yaml
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
  widgets/
    app_card.dart            # AppCard - consistent card container
    shimmer_skeleton.dart    # ShimmerSkeleton - loading placeholder
    app_empty_state.dart     # AppEmptyState - empty list/data state
    app_badge.dart           # AppBadge - colored status chip
    app_toast.dart           # AppToast - centralized toast helper
```

### Pattern 1: Reusable Widget with Theme Integration
**What:** Each widget reads from `AppColors` and the existing `ThemeData` -- no hardcoded colors.
**When to use:** Every new widget in `lib/widgets/`.
**Example:**
```dart
// lib/widgets/app_card.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000), // 3% black
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
```

### Pattern 2: Shimmer Skeleton (Pure Flutter)
**What:** Animated gradient sweep creating a loading placeholder without external packages.
**When to use:** Replace every `CircularProgressIndicator` for list/card loading states.
**Example:**
```dart
// lib/widgets/shimmer_skeleton.dart
import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
            end: Alignment(-1.0 + 2.0 * _ctrl.value + 1.0, 0),
            colors: const [
              Color(0xFFE5E7EB), // AppColors.border
              Color(0xFFF3F4F6), // AppColors.surfaceVariant
              Color(0xFFE5E7EB),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Pattern 3: Centralized Toast Helper
**What:** Static helper wrapping `toastification.show()` with brand-consistent defaults.
**When to use:** Replace ALL `ScaffoldMessenger.of(context).showSnackBar(...)` calls in admin screens.
**Example:**
```dart
// lib/widgets/app_toast.dart
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../core/theme.dart';

class AppToast {
  static void success(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  static void error(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }

  static void info(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }
}
```

### Pattern 4: Empty State Widget
**What:** Reusable empty state with icon, heading, and subtext.
**When to use:** When data fetches return empty lists (no employees, no logs, no reports).
**Example:**
```dart
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String? subtext;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.heading,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 8),
            Text(subtext!,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
```

### Pattern 5: Status Badge Chip
**What:** Colored chip for attendance status display.
**When to use:** Hadir/Sakit/Izin/BelumPulang status in lists and detail views.
**Example:**
```dart
class AppBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const AppBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  // Named constructors for common statuses
  factory AppBadge.hadir() => const AppBadge(
    label: 'Hadir',
    backgroundColor: AppColors.badgeMasukBg,
    textColor: AppColors.badgeMasukText,
  );
  // ... sakit, izin, belumPulang variants

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
```

### Anti-Patterns to Avoid
- **Inline BoxDecoration duplication:** Every card currently builds its own Container with decoration. Migrate to `AppCard`.
- **Raw CircularProgressIndicator:** Replace with `ShimmerSkeleton` composites (e.g., `_DashboardShimmer`, `_EmployeeListShimmer`).
- **ScaffoldMessenger.showSnackBar:** Replace with `AppToast.success/error/info` for consistency.
- **Hardcoded colors in screen files:** Use `AppColors` constants exclusively.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toast notifications | Custom overlay/snackbar system | `toastification` (already installed) | Animation, positioning, auto-dismiss all handled |
| Shimmer animation math | Complex shader or external package | `LinearGradient` + `AnimationController` | Phase 6 already proved this pattern works well in the project |
| Bottom nav pill indicator | Manual positioned Container | `AnimatedContainer` with brand color fill | Simpler, animates naturally |

**Key insight:** This phase has zero new package requirements. Everything is achievable with Flutter built-ins + already-installed `toastification`. The value is in CONSISTENCY, not new capabilities.

## Common Pitfalls

### Pitfall 1: Shimmer Memory Leak
**What goes wrong:** `AnimationController` not disposed when widget unmounts.
**Why it happens:** Forgetting `dispose()` or using shimmer in a `StatelessWidget`.
**How to avoid:** Always use `StatefulWidget` with `SingleTickerProviderStateMixin` and explicit `_ctrl.dispose()` in `dispose()`. The project already follows this pattern in Phase 6 kiosk background.
**Warning signs:** "A AnimationController was used after being disposed" error in console.

### Pitfall 2: Toast Context Loss
**What goes wrong:** `toastification.show(context: context)` fails because context is no longer mounted.
**Why it happens:** Async operations complete after navigation.
**How to avoid:** Always guard with `if (!mounted) return;` before showing toast. The kiosk code already does this correctly.
**Warning signs:** "Looking up deactivated widget's ancestor" error.

### Pitfall 3: Breaking Existing SnackBar Callbacks
**What goes wrong:** Some SnackBars have `action:` with undo/retry callbacks. Blindly replacing with toast loses functionality.
**Why it happens:** Batch find-replace without reading each usage.
**How to avoid:** Audit each SnackBar usage individually. For action-bearing SnackBars, use `toastification` with custom widget or keep SnackBar for that specific case.
**Warning signs:** Lost undo/retry functionality after migration.

### Pitfall 4: Inconsistent Card Padding After Refactor
**What goes wrong:** `AppCard` has default padding, but some cards have custom inner layouts that conflict.
**Why it happens:** Not all card uses have the same padding needs.
**How to avoid:** Make `padding` a nullable parameter on `AppCard`. When `null`, apply default 16dp. When explicit, use that value. Allow `padding: EdgeInsets.zero` for cards with custom inner layout.

### Pitfall 5: withOpacity() Deprecation
**What goes wrong:** Using `Color.withOpacity()` which is deprecated in Flutter 3.27+.
**Why it happens:** Old habit from pre-3.27 code.
**How to avoid:** Use `Color.withValues()` as done in Phase 6 (`kioskNfc*` constants). For new code, prefer pre-defined color constants in `AppColors` when the opacity is reused.
**Warning signs:** Deprecation warnings in `flutter analyze`.

## Code Examples

### Current Admin Dashboard Card Pattern (to be replaced)
```dart
// Current: inline Container with manual decoration in admin_dashboard_screen.dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  ),
  child: ...
)
```

### Target Pattern (after refactor)
```dart
// After: using AppCard from lib/widgets/
AppCard(
  child: Row(
    children: [
      _StatIcon(icon: Icons.login, color: AppColors.success),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Masuk Hari Ini', style: TextStyle(fontWeight: FontWeight.w500)),
          Text('$_todayMasuk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
    ],
  ),
)
```

### Shimmer Composite for Dashboard
```dart
// Shimmer loading state for dashboard metric cards
Widget _buildDashboardShimmer() {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.6,
    children: List.generate(4, (_) => AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerSkeleton(width: 32, height: 32, borderRadius: 8),
          SizedBox(height: 12),
          ShimmerSkeleton(width: 80, height: 12),
          SizedBox(height: 8),
          ShimmerSkeleton(width: 48, height: 24),
        ],
      ),
    )),
  );
}
```

### Bottom Nav Pill Indicator
```dart
// Current: background color with 10% opacity on selected
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: selected
        ? AppColors.primary.withOpacity(0.1)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Icon(...)
)

// Target: brand color pill with higher contrast
AnimatedContainer(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOutCubic,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  decoration: BoxDecoration(
    color: selected ? AppColors.primaryLight : Colors.transparent,
    borderRadius: BorderRadius.circular(20), // more pill-like
  ),
  child: Icon(
    selected ? activeIcon : icon,
    color: selected ? AppColors.primary : AppColors.textSecondary,
    size: 22,
  ),
)
```

### Toast Migration Example
```dart
// BEFORE (current admin pattern):
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Berhasil disimpan')),
);

// AFTER:
AppToast.success(context, 'Berhasil disimpan');
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Color.withOpacity()` | `Color.withValues()` or pre-defined constants | Flutter 3.27 (late 2024) | Avoid deprecation warnings |
| `shimmer` package | Pure Flutter `LinearGradient` + `AnimationController` | Always available | No dependency needed, full control |
| Raw `SnackBar` | `toastification` with branded styling | Already in project | Consistent, animated, positioned |

## Open Questions

1. **SnackBars with action callbacks**
   - What we know: Some admin SnackBars may have `action:` parameters (undo, retry)
   - What's unclear: Exact count of action-bearing SnackBars
   - Recommendation: Audit during plan creation; for action SnackBars, either use toastification's custom widget slot or keep SnackBar for those specific cases

2. **Card shadow depth across screens**
   - What we know: Dashboard cards want "proper shadow + icon" per requirements
   - What's unclear: Whether all screens should use identical shadow or varying elevation
   - Recommendation: Single `AppCard` with one consistent shadow. If metric cards need emphasis, use a slightly different background color, not heavier shadow.

## Sources

### Primary (HIGH confidence)
- **Project codebase analysis** - `lib/core/theme.dart`, `lib/core/constants.dart`, `lib/screens/admin/*.dart`, `pubspec.yaml`
- **toastification v2.3.0** - Already installed and configured in `app.dart` with `ToastificationWrapper`
- **Phase 6 precedent** - `CustomPainter` shimmer + `AnimationController` pattern proven in kiosk idle screen

### Secondary (MEDIUM confidence)
- **Flutter Material 3 guidelines** - Card elevation, bottom nav patterns, shimmer loading conventions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new packages, everything already installed
- Architecture: HIGH - Widget library pattern is standard Flutter, project structure is well understood
- Pitfalls: HIGH - Based on direct codebase analysis (43 SnackBar usages, 16+ loading states, inline decoration patterns)

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable -- no fast-moving dependencies)

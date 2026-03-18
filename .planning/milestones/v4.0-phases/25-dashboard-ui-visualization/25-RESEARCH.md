# Phase 25: Dashboard UI + Visualization - Research

**Researched:** 2026-03-19
**Domain:** Flutter charting (fl_chart), dashboard composition, gamification UI, memory-safe kiosk widgets
**Confidence:** HIGH

## Summary

Phase 25 builds a chart dashboard screen using fl_chart and integrates streak gamification into the kiosk scan flow. The foundation is solid: Phase 23 deployed all 4 Supabase RPCs (get_attendance_rates, get_weekly_trend, get_outlet_comparison, update_employee_streak) and Phase 24 delivered AnalyticsService with data models plus AttendanceRateCard and OvertimeAlertRow widgets. The dashboard is a new screen (`ChartDashboardScreen`) added as a GoRouter route under the admin ShellRoute, composed of 6 sections in a scrollable ListView. The gamification work requires modifying `KioskScanScreen._buildSuccess()` to show streak count and calling `update_employee_streak` RPC + badge auto-award on masuk scans.

fl_chart is the only new dependency. The latest version on pub.dev is 1.2.0 (published March 2026), but the REQUIREMENTS.md specifies `^0.69.0` which was the version when the requirements were written. Use `fl_chart: ^0.69.0` as specified -- it is compatible with Flutter SDK >=3.3.0. The API is stable: PieChart and BarChart widgets take declarative data objects (PieChartData, BarChartData) and render efficiently without external controllers to dispose.

**Primary recommendation:** Build the dashboard as a single StatefulWidget with AutomaticKeepAliveClientMixin, load each section independently via Future.wait, and use RefreshIndicator for pull-to-refresh. For gamification, call update_employee_streak RPC fire-and-forget after masuk scan and check milestone thresholds client-side.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DASH-01 | Mini chart dashboard -- single scrollable screen with donut, trend, leaderboard, overtime | ChartDashboardScreen layout in UI-SPEC; fl_chart PieChart + BarChart APIs; existing AttendanceRateCard/OvertimeAlertRow widgets |
| DASH-02 | Dashboard uses fl_chart for chart rendering | fl_chart ^0.69.0 API verified; PieChartData/BarChartData constructors documented below |
| DASH-03 | Admin sees cross-outlet comparison as grouped bar chart | get_outlet_comparison RPC exists (Phase 23); BarChartGroupData supports multiple barRods per group; role check via `appState.isAdmin` |
| DASH-04 | Memory-safe for 24/7 kiosk (AutomaticKeepAliveClientMixin, proper disposal) | fl_chart has no controllers to dispose; Timer/StreamSubscription must be disposed; avoid withOpacity() in paint |
| GAME-02 | Streak counter visible on kiosk scan result after masuk | KioskScanScreen._buildSuccess() identified; update_employee_streak RPC returns current_streak; inject after confetti/checkmark |
| GAME-03 | Auto-badge at streak milestones (7, 30, 90 days) | BadgeService.assignBadge() exists; need StreakBadgeService to check milestones and call BadgeService |
| GAME-04 | Streak leaderboard on admin dashboard (top 5) | employee_streaks table exists with current_streak column; query with order + limit 5 |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | ^0.69.0 | PieChart (donut), BarChart (weekly trend, grouped comparison) | Pure Dart, no native code, lightweight for kiosk; specified in REQUIREMENTS.md DASH-02 |

### Supporting (Already in pubspec.yaml)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_riverpod | ^2.6.1 | State management for dashboard providers | ConsumerStatefulWidget for ChartDashboardScreen |
| go_router | ^14.8.1 | Navigation to/from chart dashboard | Add route `/admin/chart-dashboard` |
| supabase_flutter | ^2.8.4 | RPC calls for chart data | AnalyticsService already wraps RPCs |
| confetti | ^0.8.0 | Streak milestone celebration | Reuse existing _confettiCtrl in KioskScanScreen |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart | syncfusion_flutter_charts | Heavier, license concerns, overkill for 4 charts |
| fl_chart | graphic | Less mature, fewer examples |
| Hand-rolled donut | CustomPainter | More code, less maintainable, fl_chart already handles touch |

**Installation:**
```bash
C:\flutter\bin\flutter.bat pub add fl_chart
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
  screens/admin/
    chart_dashboard_screen.dart    # NEW: main dashboard with all chart sections
  services/
    analytics_service.dart          # EXISTS: getAttendanceRates, getOvertimeFlags
    streak_service.dart             # NEW: wraps update_employee_streak RPC + leaderboard query
    badge_service.dart              # EXISTS: assignBadge for milestone auto-award
  widgets/
    attendance_rate_card.dart       # EXISTS: reuse as-is
    overtime_alert_row.dart         # EXISTS: reuse as-is
```

### Pattern 1: Section-Independent Loading
**What:** Each dashboard section loads its data independently. If one RPC fails, others still render.
**When to use:** Always for the chart dashboard screen.
**Example:**
```dart
// Load all sections in parallel, each with independent error handling
Future<void> _loadAllSections() async {
  await Future.wait([
    _loadAttendanceRate(),
    _loadWeeklyTrend(),
    _loadOvertimeFlags(),
    _loadStreakLeaderboard(),
    if (_isAdmin) _loadOutletComparison(),
  ]);
}
```

### Pattern 2: Singleton Service with supabaseReady Guard
**What:** All services follow the singleton pattern with `supabaseReady` guard, matching AnalyticsService and PatternDetectionService.
**When to use:** For the new StreakService.
**Example:**
```dart
class StreakService {
  StreakService._();
  static final instance = StreakService._();

  Future<Map<String, dynamic>?> updateStreak(String employeeId) async {
    if (!supabaseReady) return null;
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'update_employee_streak',
        params: {'p_employee_id': employeeId},
      );
      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[StreakService] updateStreak failed: $e');
      return null;
    }
  }
}
```

### Pattern 3: Role-Based Section Visibility
**What:** Use `ref.watch(appProvider).isAdmin` to conditionally render admin-only sections.
**When to use:** Cross-outlet comparison chart (Section 6 in UI-SPEC).
**Example:**
```dart
final appState = ref.watch(appProvider);
// ...in ListView children:
if (appState.isAdmin) _buildOutletComparisonSection(),
```

### Pattern 4: Outlet ID Resolution
**What:** Admin selects outlet from dropdown (existing `_selectedOutletId` in AdminDashboardScreen). Kepala Gerai auto-scoped to `managedOutletId`.
**When to use:** All RPC calls from the chart dashboard.
**Example:**
```dart
String get _effectiveOutletId {
  final appState = ref.read(appProvider);
  if (appState.isKepalaGerai) return appState.managedOutletId!;
  return _selectedOutletId ?? _outlets.first.id;
}
```

### Anti-Patterns to Avoid
- **withOpacity() in paint/build:** Creates a new Color object every frame. Use pre-defined `AppColors` constants or `Color(0xXXRRGGBB)` literals. The UI-SPEC explicitly warns about this.
- **Fetching all attendance logs in Dart:** DASH-05 requires all aggregations via Supabase RPC. Never `SELECT * FROM attendance_logs` and compute in Dart.
- **Single global error state:** Each section must have its own loading/error/data state. A slow or failed RPC must not block other sections.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Donut chart | CustomPainter arc drawing | `PieChart` from fl_chart | Touch tooltips, animations, legend support built in |
| Bar chart | Canvas drawRect | `BarChart` from fl_chart | Grouped bars, axis labels, touch data all handled |
| Streak calculation | Client-side consecutive-day counting | `update_employee_streak` RPC | Noon-rule logic already implemented in SQL; running in Dart would require fetching all attendance logs |
| Chart shimmer loading | Manual AnimatedOpacity | Existing `ShimmerSkeleton` widget | Already built, consistent with app patterns |

**Key insight:** All data aggregation is server-side SQL (DASH-05 completed in Phase 23). The Flutter side only calls RPCs and renders results. This keeps the client thin and kiosk-safe.

## Common Pitfalls

### Pitfall 1: fl_chart Version Mismatch
**What goes wrong:** Using `fl_chart: ^1.0.0` (latest) may change API surface vs `^0.69.0` specified in requirements.
**Why it happens:** pub.dev shows 1.2.0 as latest but REQUIREMENTS.md locked `^0.69.0`.
**How to avoid:** Use `fl_chart: ^0.69.0` as specified. The API differences between 0.69 and 1.x may include breaking changes to chart data constructors.
**Warning signs:** Compilation errors on PieChartData or BarChartData constructors after pub get.

### Pitfall 2: Memory Leak from Timer in Dashboard
**What goes wrong:** Dashboard auto-refresh timer not disposed causes memory leak in 24/7 kiosk.
**Why it happens:** If the dashboard has any periodic refresh Timer, navigating away without disposing leaks.
**How to avoid:** Cancel all Timers in `dispose()`. Use `AutomaticKeepAliveClientMixin` so the widget survives tab switches but still properly disposes on removal.
**Warning signs:** Growing memory in DevTools profiler after repeated navigation.

### Pitfall 3: GoRouter Route Not in ShellRoute
**What goes wrong:** New chart dashboard route placed outside ShellRoute loses bottom nav and app bar.
**Why it happens:** AdminShell provides the AppBar + BottomNav via ShellRoute builder.
**How to avoid:** Add the new route INSIDE the existing ShellRoute's `routes` list. The chart dashboard should be a full-screen push from the admin dashboard, so it needs its OWN AppBar (not the shell's) -- meaning it should be a standalone GoRoute OUTSIDE the ShellRoute, with its own back-arrow AppBar.
**Warning signs:** Missing bottom nav or double app bar.

### Pitfall 4: Streak RPC Called Without Auth Context
**What goes wrong:** `update_employee_streak` RPC has SECURITY DEFINER with role checks. Kiosk mode uses the kiosk Supabase client which may not have admin JWT.
**Why it happens:** Kiosk scan runs under `SupabaseClientFactory.kiosk`, not `.admin`.
**How to avoid:** The streak update after masuk scan should use `SupabaseClientFactory.admin` (same as AnalyticsService pattern), OR create a separate RPC callable by the kiosk role.
**Warning signs:** "Not authorized to update streaks" error in logs.

### Pitfall 5: Donut Chart Center Text Not Centered
**What goes wrong:** PieChart center text drifts off-center when `centerSpaceRadius` is wrong.
**Why it happens:** fl_chart's `centerSpaceRadius` must be explicitly set for donut style.
**How to avoid:** Set `centerSpaceRadius` to a fixed value (e.g., 60) and overlay a `Positioned` or `Stack` center widget for the percentage text, rather than relying on fl_chart's built-in center rendering.
**Warning signs:** Text visually misaligned on different screen sizes.

## Code Examples

### PieChart Donut (Attendance Rate)
```dart
// Source: fl_chart official docs + UI-SPEC
PieChart(
  PieChartData(
    sections: [
      PieChartSectionData(
        value: attendanceRate,
        color: AppColors.success,
        radius: 24,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 100 - attendanceRate,
        color: AppColors.danger,
        radius: 24,
        showTitle: false,
      ),
    ],
    centerSpaceRadius: 60,
    sectionsSpace: 2,
    startDegreeOffset: -90,
    pieTouchData: PieTouchData(enabled: false),
  ),
)
```

### BarChart Weekly Trend
```dart
// Source: fl_chart docs + UI-SPEC
BarChart(
  BarChartData(
    barGroups: weeklyData.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.count.toDouble(),
            color: AppColors.success,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList(),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
            return Text(labels[value.toInt()], style: const TextStyle(fontSize: 10));
          },
        ),
      ),
    ),
    barTouchData: BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF111827),
        tooltipBorderRadius: BorderRadius.circular(8),
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            '${rod.toY.toInt()} hadir',
            const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          );
        },
      ),
    ),
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
  ),
)
```

### Grouped Bar Chart (Outlet Comparison)
```dart
// Source: fl_chart docs + UI-SPEC
// Outlet colors assigned alphabetically
const _outletColors = [
  Color(0xFFDC2626), // red
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
  Color(0xFF14B8A6), // teal
];

BarChart(
  BarChartData(
    barGroups: outletData.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.rate,
            color: _outletColors[entry.key % _outletColors.length],
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList(),
    maxY: 100,
    // ... titles, touch, grid config
  ),
)
```

### Streak Display on Kiosk Scan Success
```dart
// Insert after the existing "Berhasil!" / typeLabel section in _buildSuccess()
if (_submittedType == AttendanceType.masuk && _currentStreak >= 2)
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.local_fire_department, size: 24, color: AppColors.warning),
      const SizedBox(width: 8),
      Text(
        '$_currentStreak hari berturut-turut!',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  ),
```

### AutomaticKeepAliveClientMixin Usage
```dart
class _ChartDashboardScreenState extends ConsumerState<ChartDashboardScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build for keepalive
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Kehadiran')),
      body: RefreshIndicator(
        onRefresh: _loadAllSections,
        child: ListView(children: [...]),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fetch-all-compute-in-Dart | Server-side RPC aggregation (DASH-05) | Phase 23 | Client only renders; no heavy computation |
| fl_chart 0.55-0.65 | fl_chart 0.69+ / 1.x | 2025 | Better gradient support, cornerRadius on pie sections |
| Manual streak counting | SQL noon-rule RPC | Phase 23 | Correct cross-midnight handling |

**Deprecated/outdated:**
- AttendanceRateCard has a `GestureDetector.onTap` showing a snackbar "Dashboard lengkap segera hadir" -- this should be replaced with actual navigation to the chart dashboard

## Existing Codebase Integration Points

### AnalyticsService (lib/services/analytics_service.dart)
- **Singleton:** `AnalyticsService.instance`
- **Methods:** `getAttendanceRates(outletId, start, end)`, `getOvertimeFlags(outletId, date, thresholdHours)`, `getMissingClockouts(outletId, thresholdHours)`
- **Data classes:** `AttendanceRateData`, `OvertimeFlag`, `MissingClockout`
- **Pattern:** Returns null/empty on failure (non-throwing)

### BadgeService (lib/services/badge_service.dart)
- **Singleton:** `BadgeService.instance`
- **For auto-award:** `assignBadge(employeeId, badgeId)` -- assigns badge to employee
- **For creating streak badges:** `createBadge(name, emoji, borderColor, borderStyle)` -- creates badge definition
- **Note:** BadgeService manages visual badge definitions. Auto-award needs to: (1) check if streak milestone badge exists, (2) create if not, (3) assign to employee

### KioskScanScreen (lib/screens/kiosk/kiosk_scan_screen.dart)
- **Success method:** `_buildSuccess(Employee? employee)` at line ~647
- **Injection point:** After `employee.name` Text widget and badge label, before the "Kembali ke layar utama..." row
- **Available controllers:** `_confettiCtrl` (for milestone celebration), `_successScaleCtrl`
- **Submitted type:** `_submittedType` -- check `== AttendanceType.masuk` to show streak
- **Employee ID:** `ref.read(appProvider).detectedEmployee?.id`

### GoRouter (lib/app.dart)
- **Chart dashboard route:** Add as standalone GoRoute (NOT inside ShellRoute) since it has its own AppBar with back arrow
- **Path:** `/admin/chart-dashboard`
- **Navigation:** From AdminDashboardScreen via `context.push('/admin/chart-dashboard')`
- **Redirect guard:** Route starts with `/admin` so existing redirect logic handles auth check

### AppProvider (lib/providers/app_provider.dart)
- **Role checks:** `appState.isAdmin`, `appState.isKepalaGerai`, `appState.isAnyAdmin`
- **Outlet ID:** `appState.managedOutletId` (for kepala_gerai), admin selects from dropdown
- **Employee context:** `appState.detectedEmployee` (during kiosk scan flow)

### Supabase RPCs (sql/phase23_rpc_functions.sql)
- **get_weekly_trend(p_outlet_id, p_days):** Returns JSON array `[{date: "2026-03-19", count: 5}, ...]`
- **get_outlet_comparison(p_start, p_end):** Returns JSON array `[{outlet_id, outlet_name, total_employees, total_present, rate}, ...]`
- **update_employee_streak(p_employee_id):** Returns JSON `{current_streak: N, longest_streak: M}`, also upserts employee_streaks table
- **Role guards:** get_weekly_trend/get_attendance_rates allow admin+kepala_gerai; get_outlet_comparison is admin-only; update_employee_streak allows admin+kepala_gerai

### AdminDashboardScreen (lib/screens/admin/admin_dashboard_screen.dart)
- **Outlet context:** `_selectedOutletId` + `_outlets` list already loaded
- **Add button:** "Lihat Dashboard" button needs to be added, passing outletId to chart dashboard
- **Kepala gerai auto-scope:** Already sets `_selectedOutletId = appState.managedOutletId` in initState

## Open Questions

1. **fl_chart ^0.69.0 vs ^1.0.0**
   - What we know: REQUIREMENTS.md says ^0.69.0, pub.dev latest is 1.2.0
   - What's unclear: Whether breaking changes exist between 0.69 and 1.x
   - Recommendation: Use ^0.69.0 as specified in REQUIREMENTS.md. If pub resolution fails (0.69 may be removed), fall back to the latest compatible version.

2. **Kiosk auth for streak update**
   - What we know: update_employee_streak requires admin/kepala_gerai role. Kiosk scan uses SupabaseClientFactory.kiosk.
   - What's unclear: Whether kiosk client has a JWT with the right role for this RPC.
   - Recommendation: Call streak update via SupabaseClientFactory.admin (pattern matches PatternDetectionService). If no admin session exists in kiosk mode, the fire-and-forget call will silently fail (non-throwing pattern).

3. **Streak badge definitions**
   - What we know: BadgeService manages badge CRUD. No streak-specific badges exist yet.
   - What's unclear: Whether streak badges should be pre-created during deployment or auto-created on first milestone hit.
   - Recommendation: Pre-create 3 streak badge definitions (7-day, 30-day, 90-day) as part of Wave 0 setup, then auto-assign them on milestone.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none (uses default flutter test runner) |
| Quick run command | `C:\flutter\bin\flutter.bat test test/services/ --no-pub` |
| Full suite command | `C:\flutter\bin\flutter.bat test --no-pub` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 | ChartDashboardScreen renders all 5 sections for kepala_gerai | widget | `flutter test test/screens/admin/chart_dashboard_screen_test.dart -x` | Wave 0 |
| DASH-02 | fl_chart PieChart and BarChart render with RPC data | widget | `flutter test test/screens/admin/chart_dashboard_screen_test.dart -x` | Wave 0 |
| DASH-03 | Outlet comparison section visible only for admin role | widget | `flutter test test/screens/admin/chart_dashboard_screen_test.dart -x` | Wave 0 |
| DASH-04 | No timer/subscription leaks after dispose | unit | `flutter test test/screens/admin/chart_dashboard_screen_test.dart -x` | Wave 0 |
| GAME-02 | Streak count shown on kiosk scan success for masuk | widget | `flutter test test/screens/kiosk/kiosk_scan_streak_test.dart -x` | Wave 0 |
| GAME-03 | Auto-badge awarded at 7/30/90 milestones | unit | `flutter test test/services/streak_service_test.dart -x` | Wave 0 |
| GAME-04 | Leaderboard shows top 5 by current_streak | unit | `flutter test test/services/streak_service_test.dart -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `C:\flutter\bin\flutter.bat test test/services/ --no-pub`
- **Per wave merge:** `C:\flutter\bin\flutter.bat test --no-pub`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/services/streak_service_test.dart` -- covers GAME-02, GAME-03, GAME-04
- [ ] `test/screens/admin/chart_dashboard_screen_test.dart` -- covers DASH-01, DASH-02, DASH-03, DASH-04

*(Existing test infrastructure: test/services/ has analytics_service_test.dart and pattern_detection_test.dart from Phase 24)*

## Sources

### Primary (HIGH confidence)
- fl_chart GitHub docs: PieChart API (https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/pie_chart.md)
- fl_chart GitHub docs: BarChart API (https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/bar_chart.md)
- Codebase: lib/services/analytics_service.dart -- AnalyticsService method signatures and data classes
- Codebase: lib/services/badge_service.dart -- BadgeService CRUD methods
- Codebase: lib/screens/kiosk/kiosk_scan_screen.dart -- success screen injection point
- Codebase: lib/app.dart -- GoRouter route structure
- Codebase: sql/phase23_rpc_functions.sql -- RPC signatures and return types
- Codebase: lib/core/theme.dart -- AppColors definitions
- UI-SPEC: .planning/milestones/v4.0-phases/25-dashboard-ui-visualization/25-UI-SPEC.md

### Secondary (MEDIUM confidence)
- pub.dev fl_chart page -- version 1.2.0 latest (https://pub.dev/packages/fl_chart)

### Tertiary (LOW confidence)
- fl_chart ^0.69.0 specific API compatibility -- need to verify at pub get time

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - fl_chart is specified in REQUIREMENTS.md, all other deps already in pubspec
- Architecture: HIGH - patterns match existing codebase (singleton services, ConsumerStatefulWidget, Riverpod)
- Pitfalls: HIGH - based on direct codebase analysis (auth context, route structure, withOpacity)
- fl_chart API: MEDIUM - docs verified for current version, but ^0.69.0 specific constructors need pub get validation

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable domain, fl_chart API unlikely to change)

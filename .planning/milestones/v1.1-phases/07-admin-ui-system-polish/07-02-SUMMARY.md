---
phase: 07-admin-ui-system-polish
plan: 02
---

# Plan 07-02: Dashboard Polish & Bottom Nav Complete

## What Was Done
1. **Dashboard Refactoring**:
   - Replaced all inline metric and list `Container` items with the standardized `AppCard` widget.
   - Replaced all raw `CircularProgressIndicator` uses with custom `_buildDashboardShimmer` and `_buildListShimmer` methods that utilize the `ShimmerSkeleton` widget.
   - Replaced all raw `ScaffoldMessenger.of(context).showSnackBar` calls with `AppToast.success/error/info`.
2. **Bottom Nav Polish**:
   - Updated the `_EnakkoBottomNav` item indicator in `admin_shell.dart` to use a pill-like shape (20px border radius, wider padding).
   - Applied `AppColors.primaryLight` instead of the deprecated `withOpacity()`.
   - Polished the animation curve to `Curves.easeOutCubic` and adjusted the duration.
   - Removed deprecated `withOpacity` usages for `Color` throughout the file.

## Technical Details
- Added `shimmer_skeleton.dart`, `app_card.dart`, and `app_toast.dart` imports to `admin_dashboard_screen.dart`.
- Refactored `admin_dashboard_screen.dart` with custom local widget builder functions to encapsulate shimmer skeleton implementations for grids and lists to maintain code readability.

## Next Steps
Plan 07-03 applies the remaining widget library updates to the other admin screens (`admin_employees_screen.dart`, `admin_reports_screen.dart`, `admin_outlets_screen.dart`) and `sakit_izin_dialog.dart`.

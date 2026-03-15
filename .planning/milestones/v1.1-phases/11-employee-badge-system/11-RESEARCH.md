# Phase 11 Research: Employee Badge System

## 1. Objective

Implement REQ-M5-05: Every employee can be assigned a visual badge that renders as a colored ring around their profile photo. Badges include an emoji chip overlay. Admin can manage badge definitions (CRUD) and assign/unassign badges to employees.

---

## 2. What Already Exists

### 2.1 Database (Supabase) -- ALREADY MIGRATED

Per REQUIREMENTS.md, the database schema is **already in place**:

```sql
-- badges table (already exists)
badges (
  id          UUID PRIMARY KEY,
  name        TEXT,        -- "Employee of the Month"
  description TEXT,
  emoji       TEXT,        -- single emoji char like "🏆"
  border_color  TEXT,      -- hex color "#FFD700"
  border_color2 TEXT,      -- optional second hex for gradient
  border_style  TEXT       -- "solid" | "gradient" | "glow"
)

-- employees table (column already exists)
employees.active_badge_id  UUID FK -> badges.id  (nullable)
```

**Default seed badges already in DB:**

| Badge                  | Emoji | Border Style    |
|------------------------|-------|-----------------|
| Employee of the Month  | 🏆    | Gold gradient   |
| Star Performer         | ⭐    | Purple gradient |
| Hadir Sempurna         | 💯    | Green gradient  |
| Team Captain           | 👑    | Red glow        |
| Veteran                | 🎖️   | Gray solid      |

### 2.2 Employee Model -- NEEDS UPDATE

Current `lib/models/employee.dart` has NO `activeBadgeId` field. The model uses `select('*')` in multiple places, so the column data is returned by Supabase but silently ignored.

**Fields to add:**
- `String? activeBadgeId` -- FK to badges table

### 2.3 Avatar Rendering -- NEEDS BADGE RING WRAPPER

Avatars are rendered in **6 distinct locations** with different implementations:

| Location | File | Current Implementation | Size |
|----------|------|----------------------|------|
| Employee list card | `admin_employees_screen.dart` L540 | `CircleAvatar` + `Stack` for NFC badge | radius=26 (52dp) |
| Kiosk scan action screen | `kiosk_scan_screen.dart` L564 | `_buildAvatarCircle()` with `ClipOval` + `CachedNetworkImage` | 56dp |
| Kiosk scan success screen | `kiosk_scan_screen.dart` L633 | No avatar shown currently (just checkmark) | N/A |
| Rekap Harian tile | `admin_reports_screen.dart` L1387 | `CircleAvatar` with initial only (no photo) | radius=20 (40dp) |
| Dashboard log card | `admin_dashboard_screen.dart` L1535 | `_buildAvatar()` with `ClipRRect` + `CachedNetworkImage` | 40dp |
| Dashboard open shifts | `admin_dashboard_screen.dart` L802 | `CircleAvatar` with `NetworkImage` | radius=18 (36dp) |
| Overlay pill | `overlay_task.dart` L508 | Logo box "A" -- no employee avatar | 30dp |

**Key observation:** There is NO shared avatar widget. Each screen builds its own avatar. The `BadgeAvatar` widget we create will unify this.

### 2.4 Overlay Pill -- EMOJI ONLY (no ring)

The overlay pill (`overlay_task.dart`) runs in a separate Flutter engine isolate. It receives data via `OverlayPillState` wire payload. Currently has NO employee name or badge info. Adding badge emoji requires extending `OverlayPillState` model (add `badgeEmoji` field) and updating the overlay UI.

### 2.5 PDF Service -- BADGE NAME COLUMN

`pdf_service.dart` generates two types of attendance PDFs:
- **Per Scan PDF**: columns include Nama, Jabatan, Outlet, Jenis, Waktu, etc.
- **Rekap Harian PDF**: columns include Tanggal, Nama, Outlet, Status, etc.
- **Summary page**: per-employee table with Nama, Hadir, Avg Masuk, etc.

Badge name should be added as a column in the per-employee summary table on the summary page.

### 2.6 Widget Library (Phase 7)

Phase 7 created `lib/widgets/` with `AppCard`, `ShimmerSkeleton`, `AppEmptyState`, `AppBadge`, `AppToast`. The `AppBadge` widget is for attendance status chips (Hadir/Sakit/Izin) -- **different** from employee achievement badges. No naming conflict if we use `BadgeAvatar` for the ring widget.

### 2.7 Supabase Query Patterns

All screens that load employees use `select('*')` on the `employees` table. Since `active_badge_id` column already exists in DB, the JSON is already returned -- we just need to parse it in `Employee.fromJson()`.

Badge data needs a **separate fetch** since it's a separate table. Options:
- **Join query**: `select('*, badges(*)') ` -- Supabase supports FK joins
- **Separate fetch**: Load all badges once, cache in memory

---

## 3. Technical Analysis

### 3.1 Badge Model (`lib/models/badge.dart` -- NEW)

```dart
class EmployeeBadge {
  final String id;
  final String name;
  final String? description;
  final String emoji;
  final String borderColor;    // hex "#FFD700"
  final String? borderColor2;  // hex for gradient second color
  final String borderStyle;    // "solid" | "gradient" | "glow"

  // Parsing helpers
  Color get color1 => _parseHex(borderColor);
  Color? get color2 => borderColor2 != null ? _parseHex(borderColor2!) : null;
  BadgeBorderStyle get style => BadgeBorderStyle.fromString(borderStyle);
}

enum BadgeBorderStyle { solid, gradient, glow }
```

**Name choice:** `EmployeeBadge` (not `Badge`) to avoid collision with Flutter's `Badge` widget (Material 3).

### 3.2 BadgeService (`lib/services/badge_service.dart` -- NEW)

Responsibilities:
- Fetch all badges from `badges` table (small table, < 20 rows expected)
- Cache in memory (static `List<EmployeeBadge>`)
- Assign badge to employee: `UPDATE employees SET active_badge_id = ? WHERE id = ?`
- Unassign badge: `UPDATE employees SET active_badge_id = NULL WHERE id = ?`
- CRUD badge definitions for admin panel

**Cache strategy:** Load once on first access, refresh on admin CRUD operations. No SQLite cache needed (badges are small, read-only for kiosk, and always online for admin).

### 3.3 BadgeAvatar Widget (`lib/widgets/badge_avatar.dart` -- NEW)

Core reusable widget that replaces all ad-hoc avatar code:

```
BadgeAvatar(
  photoUrl: employee.photoUrl,
  name: employee.name,           // for initial fallback
  size: 52,                      // diameter
  badge: employeeBadge,          // nullable -- no badge = no ring
)
```

**Rendering approach:**

1. **No badge** (badge == null): Plain `CircleAvatar` / `ClipOval` + `CachedNetworkImage` (same as current behavior)

2. **Solid ring**: `Container` with `BoxDecoration(border: Border.all(color: badge.color1, width: ringWidth))` wrapping the avatar with a small padding gap

3. **Gradient ring**: `CustomPaint` with `SweepGradient` using `badge.color1` and `badge.color2`. Similar pattern to `_GradientRingPainter` already used in kiosk idle screen (Phase 6 Plan 02)

4. **Glow ring**: Solid border + `BoxShadow(color: badge.color1, spreadRadius, blurRadius)` for outer glow effect

5. **Emoji chip overlay**: `Positioned(bottom, right)` with a small circle containing the emoji text, positioned at bottom-right of the avatar Stack

**Ring width scaling:**
- Large avatars (52-56dp): 3px ring, 2px gap
- Medium avatars (40dp): 2.5px ring, 1.5px gap
- Small avatars (36dp): 2px ring, 1px gap

### 3.4 Employee Model Update

Add to `Employee`:
```dart
final String? activeBadgeId;
```

Update `fromJson`, `toJson`, `copyWith` to include `activeBadgeId`.

**No breaking changes**: field is nullable, defaults to null, existing code unaffected.

### 3.5 Badge Resolution Strategy

Two approaches for resolving `activeBadgeId` -> `EmployeeBadge`:

**Option A: In-memory badge map (RECOMMENDED)**
- `BadgeService` loads all badges once -> `Map<String, EmployeeBadge>`
- Widget resolves: `BadgeService.getBadgeById(employee.activeBadgeId)`
- Pros: Simple, efficient, badges rarely change
- Cons: Stale if admin changes badge definitions on another device (but acceptable -- refresh on admin screen open)

**Option B: Supabase JOIN in every query**
- Change `select('*')` to `select('*, badges(*)')` everywhere employees are queried
- Pros: Always fresh
- Cons: Requires changing every employee query, more complex parsing, heavier queries

**Decision: Option A** -- cache badge definitions in memory. Only ~5-20 badges total. Refresh cache when admin opens badge management screen.

### 3.6 Display Integration Points

| Surface | What to show | Data source |
|---------|-------------|-------------|
| Employee list card | Ring around CircleAvatar + emoji chip | Employee.activeBadgeId + BadgeService cache |
| Kiosk scan action | Ring around avatar in employee card | Employee from AppProvider + BadgeService cache |
| Kiosk scan success | Badge label text under employee name | Employee from AppProvider + BadgeService cache |
| Rekap Harian tile | Ring around initial avatar | Employee from DailySummary + BadgeService cache |
| Dashboard log card | Ring around avatar | Employee from join query + BadgeService cache |
| Overlay pill | Badge emoji after employee name/outlet | OverlayPillState.badgeEmoji (new field) |
| PDF summary table | "Badge" column with badge name text | Badge name resolved during PDF generation |

### 3.7 Overlay Pill Badge Integration

The overlay pill runs in a **separate Flutter isolate** and receives data via `OverlayPillState` wire payload. To show badge emoji:

1. Add `String badgeEmoji` field to `OverlayPillState` (default: empty string)
2. In `kiosk_scan_screen.dart` `_pushAttendanceOverlayEvent()`: resolve employee badge emoji and include in payload
3. In `overlay_task.dart` `_buildExpanded()`: if `badgeEmoji` is not empty, show it after the outlet name or attendance label
4. Wire payload version stays at `v:1` (additive field, backward compatible via fromMap defaults)

### 3.8 Admin Badge Management Screen

New screen for CRUD badge definitions:

- **List view**: Card per badge showing ring preview + name + emoji + style
- **Add/Edit dialog**: Name, emoji picker (simple text field for now), color picker (hex or predefined palette), second color (for gradient), style selector (solid/gradient/glow)
- **Delete**: Soft check -- if badge is actively assigned to any employee, warn before delete

**Navigation**: Add as menu item in admin shell or accessible from employee detail screen.

### 3.9 Admin Employee Detail -- Badge Picker

In `admin_employees_screen.dart`:
- Add "Assign Badge" option to the existing `PopupMenuButton` (alongside Edit, Sakit/Izin, Sakit/Izin History)
- Opens a bottom sheet or dialog listing all available badges
- Each badge shown with ring preview + name + emoji
- Tap to assign, with a "Remove Badge" option at the bottom
- Save: `BadgeService.assignBadge(employeeId, badgeId)`

---

## 4. Dependency Analysis

### 4.1 Phase 7 Dependency (Widget Library) -- SATISFIED

Phase 7 is complete. We have:
- `AppCard` for consistent card styling
- `ShimmerSkeleton` for loading states
- `AppToast` for feedback
- Color palette in `AppColors`

The new `BadgeAvatar` widget will live alongside these in `lib/widgets/`.

### 4.2 No New Flutter Packages Needed

All rendering is achievable with standard Flutter APIs:
- `CustomPaint` for gradient ring (SweepGradient -- same technique as Phase 6 `_GradientRingPainter`)
- `BoxDecoration` for solid ring and glow shadow
- `CachedNetworkImage` already in pubspec for photo loading
- No emoji picker package needed -- simple `TextField` for emoji input (admin will paste emoji)

### 4.3 Database -- ALREADY READY

Both `badges` table and `employees.active_badge_id` column already exist in Supabase. No migration needed. Seed badges already populated.

**RLS check:** Need to verify that `badges` table has appropriate RLS policies:
- Kiosk anon key: SELECT allowed (needed for badge display)
- Admin auth: SELECT, INSERT, UPDATE, DELETE allowed
- If missing, create policies before implementation

---

## 5. Risk Assessment

### 5.1 Low Risk

| Risk | Mitigation |
|------|-----------|
| `BadgeAvatar` performance with `CustomPaint` | Same technique as Phase 6 kiosk ring -- proven performant |
| Employee model change breaking existing code | New field is nullable with null default -- fully backward compatible |
| Overlay pill payload size increase | One emoji character adds ~4 bytes -- negligible |
| Badge cache staleness | Acceptable for kiosk (5min TTL on EmployeeCacheService already exists). Admin always sees fresh on screen open |

### 5.2 Medium Risk

| Risk | Mitigation |
|------|-----------|
| 6 different avatar rendering locations | Create `BadgeAvatar` as drop-in replacement, migrate one screen at a time |
| Gradient ring on small avatars (36dp) | May look cluttered -- consider falling back to solid style below 40dp |
| Emoji rendering differences across Android versions | Use system emoji (no custom font) -- Android 7+ (minSdk 24) has good emoji support |
| RLS policies on badges table may not exist | Check and create during implementation -- additive, no risk to existing data |

### 5.3 No Risk to Production

- All changes are additive (new model, new widget, new service, new fields)
- Employee model change is backward-compatible (nullable field)
- Overlay payload is backward-compatible (fromMap uses defaults for missing fields)
- No database schema changes needed (already migrated)

---

## 6. Implementation Plan Breakdown

Recommended **3 plans** based on dependency chain:

### Plan 01: Badge Model + Service + BadgeAvatar Widget
**Scope:** Foundation layer -- model, service, reusable widget
1. Create `EmployeeBadge` model (`lib/models/employee_badge.dart`)
2. Add `activeBadgeId` field to `Employee` model (fromJson, toJson, copyWith)
3. Create `BadgeService` (`lib/services/badge_service.dart`) -- fetch all, get by ID, assign, unassign
4. Create `BadgeAvatar` widget (`lib/widgets/badge_avatar.dart`) -- solid/gradient/glow ring + emoji chip
5. Verify RLS policies on `badges` table (create if missing)

**Files:** 3 new, 1 modified
**Est. effort:** ~10min

### Plan 02: Display Badge Across All Screens
**Scope:** Replace ad-hoc avatars with `BadgeAvatar` in all 6 display surfaces + overlay pill
1. Employee list card (`admin_employees_screen.dart`): replace `CircleAvatar` Stack with `BadgeAvatar`
2. Kiosk scan screen (`kiosk_scan_screen.dart`): replace `_buildAvatarCircle` with `BadgeAvatar` + badge label in success screen
3. Rekap Harian tile (`admin_reports_screen.dart`): replace initial-only `CircleAvatar` with `BadgeAvatar`
4. Dashboard log card (`admin_dashboard_screen.dart`): replace `_buildAvatar` with `BadgeAvatar`
5. Overlay pill (`overlay_task.dart` + `overlay_pill_state.dart`): add `badgeEmoji` to payload, show in pill UI
6. PDF report (`pdf_service.dart`): add badge name column to per-employee summary table
7. Initialize badge cache on app startup in screens that need it

**Files:** 6 modified
**Est. effort:** ~15min

### Plan 03: Admin Badge Management + Assignment UI
**Scope:** Admin CRUD for badge definitions + badge picker in employee detail
1. Badge picker dialog/bottom sheet: list available badges, tap to assign, "Remove" option
2. Wire badge picker into employee card PopupMenuButton in `admin_employees_screen.dart`
3. Admin badge management screen: list all badges, add/edit/delete badge definitions
4. Navigation: add badge management entry point (admin dashboard or settings)

**Files:** 2 new, 1 modified
**Est. effort:** ~12min

---

## 7. UAT Checklist Mapping

| UAT Requirement | Plan | Verification |
|----------------|------|-------------|
| Admin bisa assign badge ke karyawan dari layar employee detail | Plan 03 | Tap PopupMenu > Assign Badge > select badge > verify ring appears |
| Karyawan tanpa badge -> foto tampil normal (no ring) | Plan 02 | Employee without activeBadgeId shows plain avatar |
| Karyawan dengan badge -> foto tampil dengan colored ring | Plan 02 | Employee with badge shows ring in all 6 locations |
| Ring style: solid / gradient / glow sesuai badge definition | Plan 01 | BadgeAvatar renders correct style per badge.borderStyle |
| Emoji badge muncul di pojok avatar (small chip overlay) | Plan 01 | BadgeAvatar shows emoji chip at bottom-right |
| Badge label tampil di kiosk scan result | Plan 02 | Kiosk success screen shows badge name under employee name |
| Admin bisa buat badge custom dari admin panel | Plan 03 | Badge management CRUD screen |
| Hapus badge dari karyawan -> kembali ke avatar normal | Plan 03 | Remove badge via picker -> ring disappears |

---

## 8. Key Decisions to Confirm Before Planning

1. **Badge cache strategy:** In-memory `Map<String, EmployeeBadge>` loaded once per screen lifecycle (recommended) -- no SQLite cache needed for < 20 badges.

2. **Gradient ring technique:** Reuse `SweepGradient` + `CustomPaint` pattern from Phase 6 kiosk idle screen (proven).

3. **Emoji input in admin CRUD:** Simple `TextField` -- admin pastes emoji from keyboard. No third-party emoji picker package (keeps dependencies minimal).

4. **Small avatar threshold:** Below 40dp diameter, gradient rings may look cluttered. Consider rendering all styles as solid below 36dp for visual clarity.

5. **Overlay pill badge display:** Show emoji only (not full badge name) in the overlay pill to preserve compact layout. Emoji appears after the outlet name text.

6. **RLS policies:** Will create SELECT for anon (kiosk), full CRUD for authenticated admin. Additive only -- no risk.

7. **No `Employee.badge` eager-load:** Keep `Employee.activeBadgeId` as a simple FK string. Resolve to `EmployeeBadge` object through `BadgeService` cache, not through Supabase JOIN. This avoids touching all existing employee queries.

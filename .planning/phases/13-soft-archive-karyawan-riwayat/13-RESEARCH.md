# Phase 13: Soft-Archive Karyawan + Riwayat - Research

**Researched:** 2026-03-11
**Domain:** Employee lifecycle management with soft-delete pattern in production Flutter/Supabase app
**Confidence:** HIGH

## Summary

Phase 13 implements employee archive (soft-delete) functionality with full history preservation for a production NFC attendance kiosk serving 4 outlets with 14 employees. This is a **foundational data model change** that all subsequent v2.0 phases depend on.

The research reveals this is a **low-risk, well-understood pattern** built entirely on existing infrastructure. The `is_active` field already exists on the `employees` table and is filtered in NFC lookup queries. The architecture requires adding a single nullable timestamp column (`archived_at`) and creating a simple history view. The primary challenge is **query audit**: 6+ distinct code paths touch the `employees` table and must be verified to handle archived employees correctly.

**Primary recommendation:** Follow the additive-only migration pattern already established in the codebase. Add `archived_at TIMESTAMPTZ DEFAULT NULL` column (backward-compatible), audit all `.from('employees')` calls for proper `is_active` filtering, create new `ArchivedEmployeesScreen` following existing `AdminEmployeesScreen` patterns, and add archive action inside the existing `_EmployeeSheet` edit form.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Archive UX flow:**
  - Default employee list shows active karyawan only (no change to current default behavior)
  - Tombol "Arsip" added to existing action button row (alongside Jadwal, Refresh, Belum Pulang) — opens Riwayat Karyawan page
  - Arsip action is inside _EmployeeSheet (edit form), NOT from PopupMenu — admin opens edit → sees "Arsipkan Karyawan" button at the bottom
  - Toggle isActive ("Karyawan Aktif") stays as-is for temporary deactivation — "Arsipkan" is a separate destructive button below the toggle
  - Two distinct actions: toggle isActive = temporary nonaktif (can still appear in lists), Arsipkan = move to archive (hidden from everything)
  - Confirmation dialog before archive: shows count of upcoming scheduled shifts that will be removed

- **Riwayat Karyawan page:**
  - Simple list with AppCard per archived employee
  - Each card shows: nama, outlet, tanggal diarsipkan (from archived_at)
  - No attendance detail on this page — just the archived employee registry
  - "Pulihkan" button per item to restore back to active list
  - Not grouped by outlet — flat list, simple
  - When restored: employee reappears in active list, can clock in via NFC again

- **Archive data model:**
  - Add `archived_at` timestamp column to employees table (nullable, additive migration)
  - `archived_at` is informational only — shows when the employee was archived
  - `is_active` remains the sole filter for all queries (NFC, schedule, dashboard, admin list)
  - Archive action: set `is_active = false` + `archived_at = NOW()`
  - Restore action: set `is_active = true` + `archived_at = NULL`
  - ⚠️ Production database — additive migration only (ADD COLUMN nullable, never DROP/ALTER existing)

### Claude's Discretion
- Exact layout/styling of Arsipkan button in _EmployeeSheet (red/destructive style expected)
- Exact layout of Riwayat Karyawan page (standard AppCard pattern)
- Empty state for Riwayat page when no archived employees
- Whether to auto-delete future schedule_entries on archive or just let is_active filter handle it
- Loading/error states
- Animation/transition when navigating to Riwayat page

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ARCH-01 | Admin can archive (soft-delete) a karyawan from the active employee list | Supabase UPDATE pattern with is_active=false + archived_at=NOW(), existing admin_employees_screen.dart edit form extension |
| ARCH-02 | Archived karyawan is excluded from NFC scan lookup (cannot clock in) | Existing `.eq('is_active', true)` filter in kiosk_idle_screen.dart line 157, EmployeeCacheService already filters is_active |
| ARCH-03 | Archived karyawan is excluded from schedule assignment and shift selector | Existing shift_scheduler_screen.dart queries already filter is_active, no changes needed |
| ARCH-04 | Archive confirmation dialog shows impact summary (jumlah jadwal mendatang yang terdampak) | Count upcoming schedule_entries with employee_id + date >= today, display in confirmation dialog following existing _AssignNfcDialog pattern |
| ARCH-05 | Admin can restore (un-archive) a previously archived karyawan | Supabase UPDATE pattern with is_active=true + archived_at=NULL, simple button action in archived employee card |
| ARCH-06 | Admin can view Riwayat Karyawan page showing archived employees with full attendance history | New screen querying `.eq('is_active', false).not('archived_at', 'is', null)`, attendance_logs table untouched (preserve history), AppCard list pattern from admin_employees_screen.dart |
</phase_requirements>

## Standard Stack

### Core (No New Dependencies)

All requirements can be implemented with the existing Flutter/Supabase stack. No new packages needed.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.8.4 | PostgreSQL client for archive/restore operations | Already used for all CRUD operations. `.update()` and `.eq()` filters are sufficient. |
| flutter_riverpod | ^2.6.1 | State management for archive UI state | Already used in admin screens. ConsumerStatefulWidget pattern established. |
| flutter/material.dart | SDK | UI components (AlertDialog, bottom sheet) | Standard Flutter UI. Confirmation dialog follows _AssignNfcDialog pattern. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| intl | ^0.19.0 | Format archived_at timestamp for Indonesian locale | Display "Diarsipkan 11 Mar 2026" on Riwayat cards |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| archived_at timestamp | deleted_at or is_archived boolean | Timestamp provides audit trail (when archived). User decided archived_at is informational, is_active remains the filter. |
| Add archive() RPC | Client-side UPDATE query | RPC would be cleaner but adds server code. Client UPDATE is established pattern (line 1245 of admin_employees_screen.dart). |
| Soft-delete library | Manual implementation | No Flutter soft-delete libraries for Supabase. Manual is 2 lines: `.update({'is_active': false, 'archived_at': 'NOW()'})`. |

**Installation:**
```bash
# No new packages required
# All dependencies already installed
```

## Architecture Patterns

### Recommended Project Structure

Archive functionality follows the existing admin screen pattern:

```
lib/screens/admin/
├── admin_employees_screen.dart    # MODIFY: Add archive action in _EmployeeSheet
├── archived_employees_screen.dart # CREATE: New Riwayat Karyawan screen
└── admin_shell.dart               # MODIFY: Add route to archived_employees_screen

lib/models/
└── employee.dart                  # MODIFY: Add archivedAt field (DateTime?)
```

### Pattern 1: Soft-Delete with Timestamp Audit Trail

**What:** Add nullable `archived_at` timestamp to track when employee was archived. Use existing `is_active` boolean as the query filter.

**When to use:** Production databases where audit trails are required and data should never be hard-deleted.

**Example:**
```dart
// Database migration (Supabase SQL Editor)
-- Safe additive migration: nullable column with default NULL
ALTER TABLE employees 
ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL;

// Model: lib/models/employee.dart
class Employee {
  final String id;
  final String name;
  final bool isActive;
  final DateTime? archivedAt; // NEW: informational timestamp
  
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'] as String,
    name: json['name'] as String,
    isActive: json['is_active'] as bool? ?? true,
    archivedAt: json['archived_at'] == null 
      ? null 
      : DateTime.parse(json['archived_at'] as String),
  );
}

// Archive action: lib/screens/admin/admin_employees_screen.dart
Future<void> _archiveEmployee(Employee employee) async {
  // 1. Confirm with impact summary
  final upcomingShifts = await _countUpcomingShifts(employee.id);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ArchiveConfirmDialog(
      employeeName: employee.name,
      upcomingShifts: upcomingShifts,
    ),
  );
  if (confirmed != true) return;
  
  // 2. Update employee record
  await SupabaseClientFactory.admin
      .from('employees')
      .update({
        'is_active': false,
        'archived_at': DateTime.now().toIso8601String(),
      })
      .eq('id', employee.id);
  
  // 3. Optional: delete future schedule_entries
  // (User discretion: could also just let is_active filter handle it)
  if (upcomingShifts > 0) {
    await SupabaseClientFactory.admin
        .from('schedule_entries')
        .delete()
        .eq('employee_id', employee.id)
        .gte('date', DateTime.now().toIso8601String().split('T')[0]);
  }
  
  // 4. Refresh employee list
  _loadData();
}

// Restore action: lib/screens/admin/archived_employees_screen.dart
Future<void> _restoreEmployee(Employee employee) async {
  await SupabaseClientFactory.admin
      .from('employees')
      .update({
        'is_active': true,
        'archived_at': null,
      })
      .eq('id', employee.id);
  
  _loadData(); // Refresh archived list
}
```

### Pattern 2: Confirmation Dialog with Impact Summary

**What:** Show admin the consequences of archiving before committing the action.

**When to use:** Destructive actions that affect related data (schedule entries).

**Example:**
```dart
class _ArchiveConfirmDialog extends StatelessWidget {
  final String employeeName;
  final int upcomingShifts;
  
  const _ArchiveConfirmDialog({
    required this.employeeName,
    required this.upcomingShifts,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.archive_outlined, 
                color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Arsipkan Karyawan?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Karyawan "$employeeName" akan dipindahkan ke arsip.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (upcomingShifts > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, 
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$upcomingShifts jadwal mendatang akan dihapus',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Karyawan tidak akan bisa absen via NFC. Riwayat absensi tetap tersimpan.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Arsipkan', 
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Count upcoming shifts
Future<int> _countUpcomingShifts(String employeeId) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final data = await SupabaseClientFactory.admin
      .from('schedule_entries')
      .select('id')
      .eq('employee_id', employeeId)
      .gte('date', today);
  return (data as List).length;
}
```

### Pattern 3: Archived Employees List Screen

**What:** Dedicated screen showing archived employees with restore capability.

**When to use:** Separate UI for viewing archived records without cluttering main list.

**Example:**
```dart
// lib/screens/admin/archived_employees_screen.dart
// Source: Based on admin_employees_screen.dart pattern

class ArchivedEmployeesScreen extends ConsumerStatefulWidget {
  const ArchivedEmployeesScreen({super.key});

  @override
  ConsumerState<ArchivedEmployeesScreen> createState() =>
      _ArchivedEmployeesScreenState();
}

class _ArchivedEmployeesScreenState 
    extends ConsumerState<ArchivedEmployeesScreen> {
  List<Employee> _archivedEmployees = [];
  List<Outlet> _outlets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Query archived employees only
      final empData = await SupabaseClientFactory.admin
          .from('employees')
          .select('*')
          .eq('is_active', false)  // Archived = not active
          .not('archived_at', 'is', null)  // Must have archive timestamp
          .order('archived_at', ascending: false);  // Most recent first

      // Load outlets for display
      final outData = await SupabaseClientFactory.admin
          .from('outlets')
          .select('*')
          .order('name');

      if (mounted) {
        setState(() {
          _archivedEmployees = (empData as List)
              .map((e) => Employee.fromJson(e as Map<String, dynamic>))
              .toList();
          _outlets = (outData as List)
              .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(
        title: const Text('Riwayat Karyawan',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? _buildShimmer()
          : _archivedEmployees.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(
                      height: 300,
                      child: AppEmptyState(
                        icon: Icons.archive_outlined,
                        heading: 'Belum Ada Karyawan Diarsipkan',
                        subtext: 'Karyawan yang diarsipkan akan muncul di sini',
                      ),
                    ),
                  ],
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _archivedEmployees.length,
                    itemBuilder: (context, i) {
                      final emp = _archivedEmployees[i];
                      final outletName = _outlets
                          .where((o) => o.id == emp.homeOutletId)
                          .map((o) => o.name)
                          .firstOrNull;
                      return _ArchivedEmployeeCard(
                        employee: emp,
                        outletName: outletName,
                        onRestore: () => _restoreEmployee(emp),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _restoreEmployee(Employee employee) async {
    try {
      await SupabaseClientFactory.admin
          .from('employees')
          .update({
            'is_active': true,
            'archived_at': null,
          })
          .eq('id', employee.id);

      if (mounted) {
        AppToast.success(context, '${employee.name} berhasil dipulihkan');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal memulihkan karyawan');
      }
    }
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Row(
                children: const [
                  ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerSkeleton(width: 140, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedEmployeeCard extends StatelessWidget {
  final Employee employee;
  final String? outletName;
  final VoidCallback onRestore;

  const _ArchivedEmployeeCard({
    required this.employee,
    required this.outletName,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              employee.initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (outletName != null)
                  Text(
                    outletName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                if (employee.archivedAt != null)
                  Text(
                    'Diarsipkan ${DateFormat('d MMM yyyy', 'id_ID').format(employee.archivedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          
          // Restore button
          ElevatedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Pulihkan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **Hard delete employees:** Destroys audit trail, breaks foreign keys on `attendance_logs`, illegal in many jurisdictions. Always soft-delete in production.
- **Reuse is_active for archive semantics:** User explicitly decided `is_active` is for temporary deactivation, `archived_at` is for lifecycle archive. Keep them separate.
- **Filter client-side instead of DB-side:** Fetching all employees then filtering `isActive` in Dart wastes bandwidth and defeats indexes. Use `.eq('is_active', true)` in query.
- **Add NOT NULL column:** Production database migration. Must be NULLABLE or have DEFAULT. NOT NULL breaks existing kiosk app INSERT statements.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Soft-delete abstraction layer | Custom ORM with archive/restore methods | Direct Supabase `.update()` queries | 2-line operations don't justify abstraction. Supabase client already handles optimistic locking and RLS. |
| Archive audit log table | Separate `archive_history` table with triggers | `archived_at` timestamp on employee record | Single timestamp is sufficient for "when archived". User doesn't need full audit trail (who archived, reason, etc.). |
| Schedule cleanup service | Background job to delete old schedule_entries | Delete in archive transaction or rely on filter | Tiny dataset (14 employees, maybe 100 schedule entries). Deleting 5-10 rows is instant, no need for async job. |

**Key insight:** This is a CRUD enhancement to an existing admin screen, not a complex data migration. The codebase pattern is "screens call Supabase directly" — no service layer abstraction. Keep it simple.

## Common Pitfalls

### Pitfall 1: Archived Employee Cache Poisoning
**What goes wrong:** `EmployeeCacheService` caches employees with 5-minute TTL. After archiving, cached employee can still NFC scan for up to 5 minutes until cache expires.

**Why it happens:** Cache is populated before archive, keyed by `nfcUid`. Archive sets `is_active=false` in database but cache doesn't know.

**How to avoid:** 
1. Add `is_active` check at scan validation point in `kiosk_scan_screen.dart`, not just at cache time
2. Show "Karyawan tidak aktif" message and prevent attendance creation
3. Optional: Clear cache entry on archive (if EmployeeCacheService exposes `invalidate()` method)

**Warning signs:** After archiving employee, they can still clock in once or twice before seeing error.

**Code example:**
```dart
// lib/screens/kiosk/kiosk_scan_screen.dart
// Add validation AFTER cache lookup, BEFORE attendance creation

final employee = await EmployeeCacheService.getByNfcUid(uid);
if (employee == null) {
  _showError('Kartu tidak terdaftar');
  return;
}

// NEW: Check is_active even if employee found in cache
if (!employee.isActive) {
  _showError('Karyawan tidak aktif. Hubungi admin.');
  return;
}

// Proceed with attendance creation...
```

### Pitfall 2: Query Audit Incompleteness
**What goes wrong:** Some queries filter `is_active`, some don't. Archived employees appear in unexpected places (reports show inactive employees, schedule assignment dropdown includes archived).

**Why it happens:** Codebase has 6+ distinct query patterns touching `employees` table. Easy to miss one location during audit.

**How to avoid:**
1. Global search for `.from('employees')` in entire codebase
2. Audit each query to determine if it should filter active employees
3. Add `.eq('is_active', true)` where needed
4. Test with archived employee: can they appear in dropdowns? reports? NFC lookup?

**Warning signs:** Archived employee shows in outlets screen employee count, appears in shift assignment dropdown, or shows in reports with "(nonaktif)" label.

**Audit checklist:**
- [ ] `lib/screens/kiosk/kiosk_idle_screen.dart` — NFC lookup query (ALREADY FILTERS is_active ✓)
- [ ] `lib/screens/admin/admin_employees_screen.dart` — Employee list (NEEDS CHANGE: currently shows all)
- [ ] `lib/screens/admin/shift_scheduler_screen.dart` — Shift assignment dropdown (ALREADY FILTERS is_active ✓)
- [ ] `lib/services/employee_cache_service.dart` — Cache population (ALREADY FILTERS is_active ✓)
- [ ] Report screens — Attendance reports (depends: archived employees should STILL show in historical reports if they have logs)

### Pitfall 3: Migration NOT NULL Constraint
**What goes wrong:** Adding `archived_at TIMESTAMPTZ NOT NULL DEFAULT NULL` fails because NOT NULL conflicts with DEFAULT NULL. Or adding without DEFAULT breaks existing kiosk app INSERT statements.

**Why it happens:** Forgetting production constraint: 4 kiosks running v1.1 app will continue to INSERT employees without `archived_at` field until they upgrade.

**How to avoid:**
1. ALWAYS use `ALTER TABLE employees ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL;` (nullable, explicit default)
2. Test migration on copy of production database before running in prod
3. Never add NOT NULL column without migration path for existing rows

**Warning signs:** Migration succeeds but kiosk INSERT fails with "column archived_at does not have a default value" error.

**Correct migration:**
```sql
-- CORRECT: Nullable column with explicit default
ALTER TABLE employees 
ADD COLUMN archived_at TIMESTAMPTZ DEFAULT NULL;

-- INCORRECT: NOT NULL without default
ALTER TABLE employees 
ADD COLUMN archived_at TIMESTAMPTZ NOT NULL;  -- ❌ FAILS

-- INCORRECT: NOT NULL with NULL default (contradiction)
ALTER TABLE employees 
ADD COLUMN archived_at TIMESTAMPTZ NOT NULL DEFAULT NULL;  -- ❌ FAILS
```

### Pitfall 4: Future Schedule Cleanup Forgotten
**What goes wrong:** Employee archived but still appears in upcoming shift assignments. Kiosk tablets show "Ahmad — Senin 15 Mar" in schedule, but Ahmad is archived and can't clock in.

**Why it happens:** `schedule_entries` table has foreign key to `employee_id` but no cascade delete. Archive only sets `is_active=false`, doesn't touch schedule_entries.

**How to avoid:**
1. User discretion: delete future schedule_entries in archive transaction (recommended)
2. Alternative: let shift scheduler query filter `is_active` when displaying shifts
3. Show impact in confirmation dialog: "5 jadwal mendatang akan dihapus"

**Warning signs:** After archiving, admin sees archived employee name in shift scheduler calendar for future dates.

**Code example:**
```dart
// Option 1: Delete future schedule_entries (recommended)
await SupabaseClientFactory.admin
    .from('schedule_entries')
    .delete()
    .eq('employee_id', employeeId)
    .gte('date', DateTime.now().toIso8601String().split('T')[0]);

// Option 2: Filter at display time (less clean)
// In shift_scheduler_screen.dart, join employees and filter is_active
```

### Pitfall 5: Restore Without Validation
**What goes wrong:** Restoring archived employee re-activates them but doesn't check if their `home_outlet_id` still exists or is active.

**Why it happens:** Simple restore is just `UPDATE employees SET is_active=true`. Doesn't validate outlet still exists or is active.

**How to avoid:**
1. Validate outlet still active before restoring (join to outlets table)
2. Show error if outlet inactive: "Outlet gerai ini sudah tidak aktif. Ubah gerai sebelum memulihkan."
3. Allow admin to change outlet during restore if needed

**Warning signs:** Restore succeeds but employee can't be assigned to shifts because outlet is inactive.

**Code example:**
```dart
Future<void> _restoreEmployee(Employee employee) async {
  // Check if home outlet still active
  if (employee.homeOutletId != null) {
    final outlet = await SupabaseClientFactory.admin
        .from('outlets')
        .select('is_active')
        .eq('id', employee.homeOutletId!)
        .maybeSingle();
    
    if (outlet == null || !(outlet['is_active'] as bool? ?? false)) {
      if (mounted) {
        AppToast.error(context, 
            'Gerai karyawan ini sudah tidak aktif. Ubah gerai dulu.');
      }
      return;
    }
  }
  
  // Proceed with restore
  await SupabaseClientFactory.admin
      .from('employees')
      .update({'is_active': true, 'archived_at': null})
      .eq('id', employee.id);
}
```

## Code Examples

Verified patterns from codebase analysis:

### Archive Action in Employee Edit Sheet

```dart
// lib/screens/admin/admin_employees_screen.dart
// Add to _EmployeeSheetState build method, after isActive toggle

// Inside _EmployeeSheet.build():
// ... existing form fields (name, position, outlet, isActive toggle) ...

// NEW: Archive section (only show for existing employees)
if (widget.employee != null)
  Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
        const Text(
          'Zona Berbahaya',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => _archiveEmployee(),
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Arsipkan Karyawan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Karyawan akan dipindahkan ke arsip dan tidak bisa absen via NFC. Riwayat absensi tetap tersimpan.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  ),

// NEW: Archive method
Future<void> _archiveEmployee() async {
  if (widget.employee == null) return;
  
  // Count upcoming shifts
  final today = DateTime.now().toIso8601String().split('T')[0];
  final upcomingData = await SupabaseClientFactory.admin
      .from('schedule_entries')
      .select('id')
      .eq('employee_id', widget.employee!.id)
      .gte('date', today);
  final upcomingShifts = (upcomingData as List).length;
  
  // Confirm
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ArchiveConfirmDialog(
      employeeName: widget.employee!.name,
      upcomingShifts: upcomingShifts,
    ),
  );
  
  if (confirmed != true) return;
  
  // Archive
  setState(() => _saving = true);
  try {
    // Update employee
    await SupabaseClientFactory.admin
        .from('employees')
        .update({
          'is_active': false,
          'archived_at': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.employee!.id);
    
    // Delete future schedule entries
    if (upcomingShifts > 0) {
      await SupabaseClientFactory.admin
          .from('schedule_entries')
          .delete()
          .eq('employee_id', widget.employee!.id)
          .gte('date', today);
    }
    
    widget.onSaved();
    if (mounted) {
      Navigator.of(context).pop();
      AppToast.success(context, 'Karyawan berhasil diarsipkan');
    }
  } catch (e) {
    if (mounted) {
      setState(() => _saving = false);
      AppToast.error(context, 'Gagal mengarsipkan karyawan');
    }
  }
}
```

### Active Employee Filter (Admin List)

```dart
// lib/screens/admin/admin_employees_screen.dart
// MODIFY: Add is_active filter to employee query

Future<void> _loadData() async {
  setState(() => _loading = true);
  try {
    final appState = ref.read(appProvider);
    final isKepalaGerai = appState.isKepalaGerai;
    final managedOutletId = appState.managedOutletId;

    // Query karyawan — MODIFY: add is_active filter
    var empFilter = SupabaseClientFactory.admin
        .from('employees')
        .select('*')
        .eq('is_active', true);  // NEW: show active only by default
    
    if (isKepalaGerai && managedOutletId != null) {
      empFilter = empFilter.eq('home_outlet_id', managedOutletId);
    }
    final empData = await empFilter.order('name');

    // ... rest of existing code ...
  } catch (e) {
    if (mounted) setState(() => _loading = false);
  }
}
```

### Riwayat Karyawan Navigation

```dart
// lib/screens/admin/admin_employees_screen.dart
// MODIFY: Add "Arsip" button to top action row

// In _AdminEmployeesScreenState.build(), add to header:
Row(
  children: [
    // ... existing title and stats ...
    const Spacer(),
    
    // NEW: Arsip button
    IconButton(
      onPressed: () => context.push('/admin/archived-employees'),
      icon: const Icon(Icons.archive_outlined),
      tooltip: 'Riwayat Karyawan',
      color: AppColors.textSecondary,
    ),
  ],
),

// lib/app.dart
// Add route to admin routes:
GoRoute(
  path: 'archived-employees',
  builder: (context, state) => const ArchivedEmployeesScreen(),
),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard delete employees | Soft-delete with archive timestamp | Industry best practice (GDPR, audit requirements) | Preserves attendance history for legal compliance, allows restore |
| Single is_active field | Separate is_active + archived_at | User decision in CONTEXT.md | is_active = temporary toggle, archived_at = lifecycle event with audit trail |
| Client-side filtering | Server-side .eq('is_active', true) | Established pattern in codebase | Better performance, respects RLS policies, reduces bandwidth |

**Deprecated/outdated:**
- None — this is a new feature, no legacy patterns to deprecate

## Open Questions

1. **Should archived employees appear in historical reports?**
   - What we know: attendance_logs table is NOT modified — all historical scans preserved
   - What's unclear: User wants "archived karyawan excluded from ... admin list" but unclear if this includes reports for past dates
   - Recommendation: Include archived employees in date-ranged reports if they have attendance_logs in that range. Archive affects future operations, not historical visibility.

2. **Should Riwayat page show attendance summary?**
   - What we know: User said "No attendance detail on this page — just the archived employee registry"
   - What's unclear: Would showing basic stats (e.g., "Total: 45 hari kerja") be useful without being "detail"?
   - Recommendation: Start with simple list per user spec. Can add stats in Phase 14+ if requested.

3. **Should archived employees be excluded from CSV export?**
   - What we know: Admin can export employee list as CSV from admin_employees_screen
   - What's unclear: Should CSV include archived employees or only active?
   - Recommendation: Export active only by default. Add "Include archived" checkbox if needed.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | None — default Flutter test runner |
| Quick run command | `flutter test test/models/employee_test.dart -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCH-01 | Archive sets is_active=false + archived_at=NOW() | unit | `flutter test test/models/employee_test.dart::test_archive_fields -x` | ❌ Wave 0 |
| ARCH-02 | NFC scan rejects archived employee | integration | Manual — requires physical NFC card + tablet | Manual-only: hardware dependency |
| ARCH-03 | Schedule selector excludes archived employees | unit | `flutter test test/screens/admin/shift_scheduler_test.dart::test_employee_filter -x` | ❌ Wave 0 |
| ARCH-04 | Confirmation dialog shows shift count | widget | `flutter test test/widgets/archive_confirm_dialog_test.dart -x` | ❌ Wave 0 |
| ARCH-05 | Restore clears archived_at and sets is_active=true | unit | `flutter test test/models/employee_test.dart::test_restore_fields -x` | ❌ Wave 0 |
| ARCH-06 | Riwayat query filters is_active=false + archived_at NOT NULL | unit | `flutter test test/screens/admin/archived_employees_test.dart::test_query_filter -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/models/employee_test.dart -x` (model changes only)
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + manual NFC test with archived employee before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/models/employee_test.dart` — covers ARCH-01, ARCH-05 (archive/restore field updates)
- [ ] `test/screens/admin/archived_employees_test.dart` — covers ARCH-06 (Riwayat query logic)
- [ ] `test/widgets/archive_confirm_dialog_test.dart` — covers ARCH-04 (confirmation dialog UI)
- [ ] `test/screens/admin/shift_scheduler_test.dart` — covers ARCH-03 (schedule filter)
- [ ] Framework install: Already installed (flutter_test is SDK package)

*Note: ARCH-02 (NFC rejection) requires physical hardware testing — cannot be automated without NFC emulator. Recommend manual test plan: archive test employee, attempt scan, verify "Karyawan tidak aktif" message.*

## Sources

### Primary (HIGH confidence)
- Codebase analysis — `.planning/codebase/ARCHITECTURE.md`, `CONVENTIONS.md`, `INTEGRATIONS.md` (analyzed 2026-03-11)
- Existing code patterns — `lib/screens/admin/admin_employees_screen.dart` (lines 71-116 query pattern, 877-1166 dialog patterns, 1172-1420 edit sheet pattern)
- Database schema — `INTEGRATIONS.md` lines 23-33 (employees table structure confirmed)
- User decisions — `13-CONTEXT.md` (gathered 2026-03-11)

### Secondary (MEDIUM confidence)
- Soft-delete patterns — Standard industry practice documented in existing research `SUMMARY.md` lines 72-94 (Pitfall 1: soft-archive breaks existing queries)
- Flutter state management — Established Riverpod patterns in codebase (no external verification needed)

### Tertiary (LOW confidence)
- None — all recommendations based on codebase analysis and user decisions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — No new dependencies needed, all patterns established in codebase
- Architecture: HIGH — Direct codebase analysis of 6 existing screens, clear soft-delete pattern
- Pitfalls: HIGH — 5 pitfalls identified from codebase audit and production constraints in STATE.md

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (30 days — stable codebase, established patterns, no framework version changes expected)

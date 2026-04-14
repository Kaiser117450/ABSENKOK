# Phase 54: Workforce Contract & Outlet Mode Foundation - Research

**Researched:** 2026-03-26
**Domain:** additive workforce metadata foundation across live Supabase tables, typed Flutter admin models, and CSV onboarding
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Existing active employees should be backfilled to `FULLTIME` as the safe rollout default.
- New or edited employees must always have a contract value before save; `null` contract states are not acceptable.
- In the add/edit employee form, the initial UI default should be `PARTTIME`, but admin or kepala gerai can switch it to `FULLTIME` before saving.
- The canonical stored system values are `FULLTIME` and `PARTTIME`.
- Archived or inactive employees keep their last known contract value for history and audit purposes.
- Existing outlets should be backfilled to `NORMAL` as the safe rollout default.
- Every active outlet must always have an operating mode value; this field should not be nullable in normal app usage.
- Only full admin should be allowed to change outlet operating mode.
- Outlet mode must be visible both in the outlet edit sheet and as a compact badge in the outlet list so rollout review is fast.
- Employee contract should be visible as a compact badge in the active employee list.
- Employee list should gain a contract filter from Phase 54 onward for rollout review and later payroll preparation.
- Kepala gerai can edit employee contract values for employees within their own locked outlet scope.
- In the employee form, contract selection should use direct segmented chips rather than a hidden dropdown.
- Contract badges should use strong but neutral branding, not red/yellow warning language that will later belong to attendance evaluation.
- The employee list should default to showing all contracts when first opened.
- Archived employee surfaces should keep showing the stored final contract value for audit consistency.
- The employee sheet does **not** need to show the selected outlet's `NORMAL` / `TWENTY_FOUR_HOUR` mode as an extra hint in Phase 54.
- Batch employee CSV import is within Phase 54 scope because it is an existing employee-creation path that now needs contract metadata.
- CSV import must require a contract column for every row.
- CSV parser should store canonical `FULLTIME` / `PARTTIME` values but may accept common aliases such as `PARTIME`, `part-time`, or case variations and normalize them.
- Legacy templates that do not include the contract column should be rejected with a clear operator-facing error instead of silently defaulting values.
- The downloadable CSV template must be updated to include the contract column and valid sample values.

### Claude's Discretion
- Exact database column names, enum implementation details, and migration choreography, as long as the live rollout stays additive and the stored values remain `FULLTIME` / `PARTTIME` plus `NORMAL` / `TWENTY_FOUR_HOUR`.
- Exact badge colors, chip styling, and layout spacing, as long as contract visuals stay distinct from future red/yellow attendance exception colors.
- Exact wording for operator-facing CSV validation errors and normalization help text.

### Deferred Ideas (OUT OF SCOPE)
- Strict lateness, short-work, excess-break, overtime, and exempt-manager evaluation belong to later phases, not Phase 54.
- Overnight-safe recap calculation and payroll matrix exports belong to Phases 57-59.
- Any automatic payroll amount calculation, overtime approval workflow, or payslip generation remains outside this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| `CONTRACT-01` | Admin or kepala gerai can assign every active employee exactly one employment contract value, `FULLTIME` or `PARTTIME`, and attendance calculations use that stored value instead of inferring hours from scan history. | Add one additive employee column with enum-backed canonical values, expose it through a typed `EmployeeContract` model, wire it into the employee sheet/list/archive surfaces, and require it in the CSV onboarding path. |
| `CONTRACT-02` | Each outlet can be classified as `NORMAL` or `TWENTY_FOUR_HOUR`, and logical-day attendance grouping uses that outlet mode when deciding whether a shift legitimately crosses midnight. | Add one additive outlet column with enum-backed canonical values, expose it through a typed `OutletOperatingMode` model, and surface it in the admin outlet list and sheet so later overnight logic can consume a stored value instead of assumptions. |
</phase_requirements>

## Summary

Phase 54 is a storage-and-surface foundation pass, not the strict payroll logic itself. The repo already has clear employee, outlet, and CSV import seams, but today those flows do not carry any typed contract or operating-mode metadata. The safest path is to add both values as additive, canonical fields at the database layer first, then propagate them through the existing Flutter models so every joined consumer gets the same typed contract story for free.

The implementation should stay deliberately narrow. Employee contract needs to appear in the active list, the add/edit sheet, the archived history surface, and the CSV import wizard because those are the operator-visible places where workforce metadata is created or audited today. Outlet mode should stay full-admin only and live inside the existing outlet list and sheet. No recap engine, portal, or payroll rule work belongs in this phase yet.

**Primary recommendation:** create one Wave 1 foundation plan for additive SQL plus typed Dart contracts, then three Wave 2 plans for employee surfaces, CSV import enforcement, and outlet-mode admin surfaces.

## Standard Stack

### Core
| Library / System | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| PostgreSQL enum types + additive `ALTER TABLE` | PostgreSQL current docs | Canonical storage for two closed sets of values | Prevents free-text drift and keeps later SQL/report logic readable. |
| Flutter Material `SegmentedButton` | Flutter Material API | Direct 2-option selection for contract and outlet mode in forms | Official control for 2-5 mutually exclusive options; no new dependency. |
| Existing `Employee` / `Outlet` model layer | Repo-local | Shared typed metadata surface for joined employee/outlet records | `AttendanceLog` and admin/report flows already compose these models instead of ad-hoc maps. |
| `flutter_test` | SDK bundled | Focused model, service, and widget coverage | Existing repo already uses it for pure models, services, and lightweight widgets. |

### Supporting
| Library / System | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| Existing `_FilterChip2` pattern in `admin_employees_screen.dart` | Repo-local | Add All / Full-time / Part-time filter states without inventing a second filter language | Use for list filtering where the existing admin page already expects compact chip affordances. |
| `CsvImportService` pure parse/validate/build pipeline | Repo-local | Centralize required contract header enforcement and alias normalization | Use for all CSV contract validation so the screen stays thin and testable. |
| Existing admin route guards in `lib/app.dart` | Repo-local | Keep outlet mode admin-only and CSV import admin-only | Reuse the current role gate instead of layering a second permission surface into the screens. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Enum-backed DB columns | Plain text columns | Slightly less migration work, but weaker guardrails and easier value drift later. |
| Direct segmented controls | Dropdowns | Dropdowns are familiar, but they hide a mandatory binary choice the user explicitly wants visible. |
| Silent CSV default to `FULLTIME` | Required contract column | Silent default is faster, but it destroys rollout auditability and contradicts the user decision. |

## Architecture Patterns

### Recommended Project Structure
```text
sql/
├── phase_54_workforce_contract_outlet_mode_20260326.sql

lib/models/
├── employee_contract.dart
├── outlet_operating_mode.dart
├── employee.dart
└── outlet.dart

lib/widgets/
├── employee_contract_badge.dart
└── outlet_mode_badge.dart

lib/screens/admin/
├── admin_employees_screen.dart
├── archived_employees_screen.dart
├── csv_import_screen.dart
└── admin_outlets_screen.dart

test/
├── models/workforce_metadata_test.dart
├── services/csv_import_service_test.dart
└── widgets/
   ├── employee_contract_badge_test.dart
   └── outlet_mode_badge_test.dart
```

### Pattern 1: Additive live-schema rollout first
**What:** Add new enum-backed columns with safe defaults, backfill existing rows, then set `NOT NULL` only after the table data satisfies the new contract.
**When to use:** Any new live-production metadata field on `employees` or `outlets`.
**Example:**
```sql
-- Source: PostgreSQL docs on enums + ALTER TABLE
CREATE TYPE public.employee_contract AS ENUM ('FULLTIME', 'PARTTIME');

ALTER TABLE public.employees
  ADD COLUMN employment_contract public.employee_contract
  DEFAULT 'FULLTIME'::public.employee_contract;

UPDATE public.employees
SET employment_contract = 'FULLTIME'::public.employee_contract
WHERE employment_contract IS NULL;

ALTER TABLE public.employees
  ALTER COLUMN employment_contract SET NOT NULL;
```

### Pattern 2: Typed metadata belongs in the shared model layer, not in screens
**What:** Parse canonical DB strings once into typed Dart enums, then let existing joined consumers inherit those fields through `Employee.fromJson(...)` and `Outlet.fromJson(...)`.
**When to use:** Any employee/outlet metadata that later attendance, reporting, or recap code will also need.
**Example:**
```dart
enum EmployeeContract { fulltime, parttime }

extension EmployeeContractX on EmployeeContract {
  String get dbValue => switch (this) {
        EmployeeContract.fulltime => 'FULLTIME',
        EmployeeContract.parttime => 'PARTTIME',
      };

  static EmployeeContract fromDb(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PARTTIME':
      case 'PART-TIME':
      case 'PARTIME':
        return EmployeeContract.parttime;
      case 'FULLTIME':
      default:
        return EmployeeContract.fulltime;
    }
  }
}
```

### Pattern 3: Explicit 2-option controls for locked choices
**What:** Use one visible segmented control for `FULLTIME` vs `PARTTIME` and `NORMAL` vs `TWENTY_FOUR_HOUR`.
**When to use:** Form fields where the user has already locked the interaction pattern to “direct segmented chips”.
**Example:**
```dart
SegmentedButton<EmployeeContract>(
  segments: const [
    ButtonSegment(
      value: EmployeeContract.fulltime,
      label: Text('Full-time'),
    ),
    ButtonSegment(
      value: EmployeeContract.parttime,
      label: Text('Part-time'),
    ),
  ],
  selected: {_selectedContract},
  onSelectionChanged: (values) {
    setState(() => _selectedContract = values.first);
  },
)
```

### Pattern 4: CSV normalization stays centralized
**What:** Parse raw contract text once, normalize common aliases to canonical DB values, and keep the preview/result UI consuming that single normalized source.
**When to use:** CSV import validation, preview tables, and payload building.
**Example:**
```dart
final normalized = EmployeeContractX.fromDb(rawContractText);

payload['employment_contract'] = normalized.dbValue;
```

### Anti-Patterns to Avoid
- **Free-text contract strings in multiple screens:** parse once in the model/service layer instead of comparing raw strings everywhere.
- **Adding `NOT NULL` before backfill:** that can break a live table migration immediately.
- **Relying on UI defaults only:** `PARTTIME` in the form is a create-screen default, not the storage contract for existing data.
- **Updating only the active employee list:** archived employee history and CSV onboarding are both explicitly in scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mandatory binary selection | Hidden dropdown or custom gesture-only chips | `SegmentedButton` or an equivalent direct segmented control | Official control, accessible, and aligned with the user requirement. |
| Canonical contract parsing | Scattered `toUpperCase()` checks in multiple files | One enum parse helper and one CSV alias map | Prevents drift between admin form, import, and future reporting code. |
| Badge styling per screen | Separate `Container` styling in each page | Shared `EmployeeContractBadge` and `OutletModeBadge` widgets | Keeps contract/mode visuals consistent and future-proof. |
| “Existing row” fallback | Manual one-off corrections in the UI | SQL backfill plus safe Dart defaults during rollout | Preserves live usability and removes migration-order fragility. |

**Key insight:** the database owns the canonical value set, the Dart model layer owns typed access, and screens should only render or edit through those two contracts.

## Common Pitfalls

### Pitfall 1: PostgreSQL enum labels are case-sensitive
**What goes wrong:** rows or tests fail when code assumes `fulltime` equals `FULLTIME`.
**Why it happens:** enum labels in PostgreSQL are stored and compared exactly as declared.
**How to avoid:** keep DB values uppercase and normalize all UI/CSV input before persistence.
**Warning signs:** `invalid input value for enum ...` errors or mixed-case strings appearing in payload builders.

### Pitfall 2: Backfill and `NOT NULL` are applied in the wrong order
**What goes wrong:** migration fails on existing production rows because null rows violate the new constraint.
**Why it happens:** `ADD COLUMN`, `UPDATE`, and `SET NOT NULL` are treated like one step instead of a sequence.
**How to avoid:** add the column with a safe constant default, backfill any remaining nulls, then set `NOT NULL`.
**Warning signs:** migration succeeds on empty dev data but fails or stalls on populated production tables.

### Pitfall 3: The form default is mistaken for the stored default
**What goes wrong:** new UI creates `PARTTIME`, but existing rows or CSV imports silently drift back to other values.
**Why it happens:** create-screen defaults and DB defaults solve different problems.
**How to avoid:** keep `PARTTIME` as the create-form default while the migration backfills existing rows to `FULLTIME`.
**Warning signs:** newly created employees look correct, but old employees or CSV imports still show null or inconsistent contract state.

### Pitfall 4: CSV header updates only the parser, not the operator surface
**What goes wrong:** legacy templates keep circulating because the screen copy and downloadable template still advertise the old 4-column schema.
**Why it happens:** parsing logic changes but the wizard copy and preview table stay stale.
**How to avoid:** update parser, validation, preview columns, upload instructions, and template generation together.
**Warning signs:** operators keep uploading old templates or asking why rows fail even though the service code “supports” contract.

### Pitfall 5: Archived history loses the last known contract
**What goes wrong:** active employee pages look correct, but archived records no longer show the stored workforce status needed for audit.
**Why it happens:** contract badges are only added to the active list.
**How to avoid:** render the same shared badge in the archived list and leave restore flow untouched.
**Warning signs:** archive cards only show name, outlet, and archived date after Phase 54 lands.

## Code Examples

Verified patterns from official sources and current repo seams:

### PostgreSQL enum-backed additive columns
```sql
-- Sources:
-- https://www.postgresql.org/docs/current/ddl-alter.html
-- https://www.postgresql.org/docs/current/datatype-enum.html

CREATE TYPE public.outlet_operating_mode AS ENUM ('NORMAL', 'TWENTY_FOUR_HOUR');

ALTER TABLE public.outlets
  ADD COLUMN operating_mode public.outlet_operating_mode
  DEFAULT 'NORMAL'::public.outlet_operating_mode;

UPDATE public.outlets
SET operating_mode = 'NORMAL'::public.outlet_operating_mode
WHERE operating_mode IS NULL;

ALTER TABLE public.outlets
  ALTER COLUMN operating_mode SET NOT NULL;
```

### Material segmented control for 2-5 options
```dart
// Source:
// https://api.flutter.dev/flutter/material/SegmentedButton-class.html

SegmentedButton<OutletOperatingMode>(
  segments: const [
    ButtonSegment(
      value: OutletOperatingMode.normal,
      label: Text('Normal'),
    ),
    ButtonSegment(
      value: OutletOperatingMode.twentyFourHour,
      label: Text('24 Jam'),
    ),
  ],
  selected: {_selectedMode},
  onSelectionChanged: (values) {
    setState(() => _selectedMode = values.first);
  },
)
```

### Joined consumers inherit the shared metadata automatically
```dart
class AttendanceLog {
  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    Employee? emp;
    if (json['employee'] is Map<String, dynamic>) {
      emp = Employee.fromJson(json['employee'] as Map<String, dynamic>);
    }

    Outlet? outl;
    if (json['outlet'] is Map<String, dynamic>) {
      outl = Outlet.fromJson(json['outlet'] as Map<String, dynamic>);
    }

    // Existing joined flows now get contract/mode fields
    // through Employee / Outlet once those models are extended.
    ...
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Implicit workforce assumptions from scan history or outlet habits | Explicit `employment_contract` and `operating_mode` storage | Phase 54 | Prepares later payroll and overnight logic to read stored truth instead of heuristics. |
| Form-only employee metadata (`name`, `position`, `outlet`) | Typed employee contract added to the shared model and admin surfaces | Phase 54 | Operator audit and later recap logic can rely on the same contract field. |
| Outlet status only (`aktif` / `non-aktif`) | Outlet status plus explicit operating-mode badge | Phase 54 | Overnight-safe grouping can use a real outlet mode instead of guessing from outlet name or behavior. |
| 4-column employee CSV template | 5-column contract-aware template | Phase 54 | Batch onboarding stops silently omitting workforce metadata. |

**Deprecated / outdated for this milestone:**
- inferring contract from position text or attendance history
- assuming every outlet is same-day only
- re-creating contract/mode labels independently in each screen

## Open Questions

1. **Should explicit-column RPCs be widened in Phase 54?**
   - What we know: most current admin flows use `select('*')` on `employees` and `outlets`, so shared model changes plus table columns already cover them.
   - What's unclear: whether any explicit-column RPC needs contract/mode before Phase 55 begins.
   - Recommendation: keep Phase 54 scoped to tables plus `select('*')` consumers now; widen explicit RPCs only in the first later phase that truly consumes those fields.

2. **What DB field names should Phase 54 choose?**
   - What we know: the user only locked the stored values, not the column names.
   - What's unclear: whether shorter names are worth the ambiguity.
   - Recommendation: use `employment_contract` on `employees` and `operating_mode` on `outlets` because both read clearly in SQL and map cleanly to Dart.

3. **Should Dart still defend against null/unknown values after the migration?**
   - What we know: the live rollout requires resilience, and existing code already uses defensive parsing in several places.
   - What's unclear: whether every environment will receive the SQL migration before the app code.
   - Recommendation: yes, keep safe Dart parsing defaults even after the SQL contract is tightened; the DB owns canonical truth, but the client should not crash during staged rollout.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` plus targeted PowerShell SQL/source smoke checks |
| Config file | `pubspec.yaml` |
| Quick run command | `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart test/services/csv_import_service_test.dart test/widgets/employee_contract_badge_test.dart test/widgets/outlet_mode_badge_test.dart` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| `CONTRACT-01` | Employee and joined model parsing expose canonical contract values safely | unit | `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart` | ❌ Wave 0 |
| `CONTRACT-01` | CSV import requires a contract column, normalizes aliases, and inserts canonical values | unit | `C:\flutter\bin\flutter.bat test test/services/csv_import_service_test.dart` | ✅ |
| `CONTRACT-01` | Employee list/archive surfaces show a neutral contract badge | widget | `C:\flutter\bin\flutter.bat test test/widgets/employee_contract_badge_test.dart` | ❌ Wave 0 |
| `CONTRACT-02` | Outlet list/sheet surfaces show and edit outlet mode consistently | widget | `C:\flutter\bin\flutter.bat test test/widgets/outlet_mode_badge_test.dart` | ❌ Wave 0 |
| `CONTRACT-01`, `CONTRACT-02` | SQL migration adds canonical columns, defaults, backfill, and `NOT NULL` contract | static | `powershell -Command "Select-String -Path 'sql/phase_54_workforce_contract_outlet_mode_20260326.sql' -Pattern 'CREATE TYPE public.employee_contract','CREATE TYPE public.outlet_operating_mode','ALTER TABLE public.employees','ALTER TABLE public.outlets','SET NOT NULL' | Measure-Object | Select-Object -ExpandProperty Count"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** run the task-local automated command in the plan
- **Per wave merge:** run `C:\flutter\bin\flutter.bat test test/models/workforce_metadata_test.dart test/services/csv_import_service_test.dart test/widgets/employee_contract_badge_test.dart test/widgets/outlet_mode_badge_test.dart`
- **Phase gate:** run `C:\flutter\bin\flutter.bat test` before `$gsd-verify-work`

### Wave 0 Gaps
- `test/models/workforce_metadata_test.dart` - typed employee/outlet contract parsing and round-trip coverage
- `test/widgets/employee_contract_badge_test.dart` - badge rendering coverage for `FULLTIME` / `PARTTIME`
- `test/widgets/outlet_mode_badge_test.dart` - badge rendering coverage for `NORMAL` / `TWENTY_FOUR_HOUR`

## Sources

### Primary (HIGH confidence)
- [Flutter API - `SegmentedButton`](https://api.flutter.dev/flutter/material/SegmentedButton-class.html) - confirmed that the official Material control is meant for a limited set of mutually exclusive options.
- [PostgreSQL docs - Modifying Tables](https://www.postgresql.org/docs/current/ddl-alter.html) - additive `ADD COLUMN`, constant defaults, and `SET NOT NULL` sequencing.
- [PostgreSQL docs - Enumerated Types](https://www.postgresql.org/docs/current/datatype-enum.html) - enum declaration, case sensitivity, and type-safety behavior.

### Secondary (MEDIUM confidence)
- [Repo: `lib/models/employee.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/employee.dart) - current employee parse/toJson/copyWith seam.
- [Repo: `lib/models/outlet.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/outlet.dart) - current outlet parse/toJson seam.
- [Repo: `lib/models/attendance_log.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/models/attendance_log.dart) - shared joined-consumer path that will inherit the new metadata.
- [Repo: `lib/screens/admin/admin_employees_screen.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_employees_screen.dart) - active employee list, filter, and bottom-sheet save flow.
- [Repo: `lib/screens/admin/archived_employees_screen.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/archived_employees_screen.dart) - archived employee audit surface.
- [Repo: `lib/screens/admin/admin_outlets_screen.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/admin_outlets_screen.dart) - outlet list and sheet flow.
- [Repo: `lib/screens/admin/csv_import_screen.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/screens/admin/csv_import_screen.dart) - CSV operator flow and template download.
- [Repo: `lib/services/csv_import_service.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/services/csv_import_service.dart) - centralized parse/validate/build pipeline.
- [Repo: `lib/app.dart`](C:/Users/HYPE R Series/Desktop/projekan/absensi apk/absensi_enakko_flutter/lib/app.dart) - role gate that already keeps `/admin/outlets` and `/admin/csv-import` admin-only.

### Tertiary (LOW confidence)
- None - this research used official documentation plus direct repository evidence.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - official docs plus existing repo structure both support the recommended approach.
- Architecture: HIGH - the repo already has clear model/screen seams and role gates for the exact surfaces this phase needs.
- Pitfalls: HIGH - official PostgreSQL docs and the current live-rollout constraints make the migration hazards concrete.

**Research date:** 2026-03-26
**Valid until:** 2026-04-25

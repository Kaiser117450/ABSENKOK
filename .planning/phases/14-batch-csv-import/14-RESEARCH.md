# Phase 14: Batch CSV Import - Research

**Researched:** 2026-03-11
**Domain:** CSV file parsing, validation pipeline, batch Supabase insert, Flutter wizard UI
**Confidence:** HIGH

## Summary

Phase 14 implements a full CSV import pipeline for batch employee onboarding. The feature is entirely admin-side (no kiosk changes needed) and follows a 4-step wizard: Upload → Preview → Confirm → Result. Two new packages are required (`csv` and `file_picker`); everything else leverages existing patterns. The codebase already demonstrates: batch insert via `.insert(List<Map>)` in `shift_scheduler_screen.dart`, CSV string generation via `StringBuffer` + `_escapeCsv()` in `admin_reports_screen.dart`, file sharing via `share_plus` + `path_provider`, and duplicate error handling via `PostgrestException` code `23505` in `sync_service.dart`.

The architecture is straightforward: a new `CsvImportScreen` (full-screen via GoRouter) with a service class `CsvImportService` handling parse → validate → insert logic. The key complexity lies in the validation layer: outlet name → UUID resolution (case-insensitive), duplicate detection (same nama + same gerai, against both DB and within CSV), and per-row error aggregation. The all-or-nothing constraint simplifies the insert path — either all rows are valid and batch-inserted in a single `.insert()` call, or the admin must fix and re-upload.

**Primary recommendation:** Build a `CsvImportService` class encapsulating parse/validate/insert logic, separate from UI. Use the `csv` package for RFC 4180 parsing, `file_picker` for SAF-based file selection, and the existing `.insert(List<Map>)` Supabase pattern for batch insert. Keep validation entirely client-side before any DB write.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Separate full screen at `/admin/csv-import` (not dialog or tab)
- Navigation: button in the existing action row alongside Jadwal, Refresh, Arsip
- Step-by-step wizard flow: **Upload → Preview → Confirm → Result**
- Preview displays a data table with columns: No, Nama, Jabatan, Gerai, Status (valid/error icon per row)
- Error display: both inline icons per row in Status column + expandable error summary panel below table
- **All-or-nothing import**: all rows must be valid before import proceeds — no partial import
- If errors found, admin must re-upload a corrected CSV (no inline editing in preview table)
- Duplicate detection: same nama + same gerai = duplicate (checked against existing DB employees AND within the CSV itself)
- App provides a "Download Template" button on the upload step
- Column headers in Indonesian: `nama`, `jabatan`, `gerai`, `foto_url`
- Comma separator only (standard CSV)
- `nama` = required (min 3 chars), `jabatan` = optional, `gerai` = required (must match existing outlet), `foto_url` = optional (external URL)
- NFC UID is NOT in CSV (assigned later via physical card tap)
- Success summary screen showing: total count imported + list of employee names grouped by outlet
- This is the final step of the wizard before admin navigates away

### Claude's Discretion
- Exact styling of wizard steps (Stepper widget or custom)
- Upload area design (drag-and-drop zone or simple file picker button)
- Loading/progress indicator during batch insert
- Empty template content (sample rows or headers only)
- Error message wording for specific validation failures
- Whether to show a "back to employees" button or auto-navigate after result

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CSV-01 | Admin can upload a CSV file to batch-add multiple karyawan at once | `file_picker` package for file selection → `csv` package for parsing → `SupabaseClientFactory.admin.from('employees').insert(List<Map>)` for batch insert. Existing batch insert pattern in `shift_scheduler_screen.dart:670`. |
| CSV-02 | CSV format supports columns: nama, jabatan, gerai (nama outlet), photo_url (link) | `csv` package `CsvToListConverter` parses headers. Map CSV columns to employee insert payload: `name`, `position`, `home_outlet_id` (resolved from gerai name), `photo_url`. |
| CSV-03 | System auto-resolves outlet name to outlet UUID (case-insensitive match) | Pre-fetch all active outlets via existing pattern `.from('outlets').select('*').eq('is_active', true)`. Build `Map<String, String>` of `lowerCaseName → id`. Match CSV `gerai` column case-insensitively. |
| CSV-04 | System shows preview screen with parsed rows before committing to database | Wizard step 2 (Preview) renders `DataTable` with columns No, Nama, Jabatan, Gerai, Status. All validation runs client-side before any DB write. |
| CSV-05 | System detects and reports duplicate karyawan (by name + outlet combination) | Two-pass duplicate check: (1) within-CSV: build `Set<String>` of `"${nama.toLowerCase()}|${outletId}"`, flag second occurrence. (2) against-DB: pre-fetch active employees, build same key set, cross-check. |
| CSV-06 | System shows per-row validation errors (missing fields, unknown outlet, duplicates) | Each parsed row gets a `CsvRowValidation` result with `List<String> errors`. Status column shows ✅/❌ icon. Expandable error panel shows grouped error list. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `csv` | ^6.0.0 | RFC 4180 CSV parsing | Handles BOM, quoted fields, commas-in-values. Project research already selected this. Hand-rolling CSV parsing is fragile. |
| `file_picker` | ^8.1.0 | Android SAF file picker | Returns `PlatformFile` with bytes for in-memory parsing. Works on minSdk 24+. No extra permissions needed. |

### Supporting (already in project)
| Library | Version | Purpose | How Used |
|---------|---------|---------|----------|
| `supabase_flutter` | ^2.8.4 | Batch insert employees | `.from('employees').insert(List<Map>)` — existing pattern |
| `share_plus` | ^10.1.4 | Template CSV download/share | Same pattern as `admin_reports_screen.dart` CSV export |
| `path_provider` | ^2.1.5 | Temp directory for template file | `getTemporaryDirectory()` — existing pattern |
| `go_router` | ^14.8.1 | Route `/admin/csv-import` | Add to admin ShellRoute — existing pattern |
| `flutter_riverpod` | ^2.6.1 | State management (if needed) | ConsumerStatefulWidget — existing pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `csv` package | Manual `split(',')` | Breaks on quoted fields, commas in names, BOM. DON'T do this. |
| `file_picker` | `image_picker` or manual intent | `image_picker` is for images only. `file_picker` is the standard for arbitrary file types. |
| `Stepper` widget | Custom step indicator | `Stepper` is heavy and opinionated. Custom step indicator row is lighter and matches app design language. **Recommend custom.** |

**Installation:**
```yaml
# Add to pubspec.yaml dependencies:
csv: ^6.0.0
file_picker: ^8.1.0
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── screens/admin/
│   └── csv_import_screen.dart    # Full wizard UI (Upload/Preview/Confirm/Result)
├── services/
│   └── csv_import_service.dart   # Parse, validate, insert logic (no UI)
└── models/
    └── csv_import_result.dart    # Data classes for parsed rows, validation results
```

### Pattern 1: Service Separation (Parse/Validate/Insert)
**What:** Keep CSV business logic in a dedicated service, separate from UI
**When to use:** Always — the wizard screen manages step navigation and rendering; the service handles data
**Example:**
```dart
// csv_import_service.dart
class CsvImportService {
  /// Parse CSV bytes into rows. Returns List<CsvRow> with raw values.
  static List<CsvRow> parseBytes(Uint8List bytes) {
    // Strip UTF-8 BOM if present
    String content = utf8.decode(bytes);
    if (content.startsWith('\uFEFF')) content = content.substring(1);
    
    final rows = const CsvToListConverter().convert(content);
    // First row = headers, remaining = data
    // Map to CsvRow objects
    ...
  }

  /// Validate all rows against outlets and existing employees.
  /// Returns per-row validation results.
  static Future<List<CsvRowValidation>> validate(
    List<CsvRow> rows,
    List<Outlet> outlets,
    List<Employee> existingEmployees,
  ) async { ... }

  /// Batch insert validated rows. All-or-nothing.
  static Future<int> insertAll(List<CsvRow> validRows, Map<String, String> outletNameToId) async {
    final payloads = validRows.map((row) => {
      'name': row.nama,
      'position': row.jabatan?.isEmpty == true ? null : row.jabatan,
      'home_outlet_id': outletNameToId[row.gerai.toLowerCase()],
      'photo_url': row.fotoUrl?.isEmpty == true ? null : row.fotoUrl,
      'is_active': true,
    }).toList();
    
    await SupabaseClientFactory.admin.from('employees').insert(payloads);
    return payloads.length;
  }
}
```

### Pattern 2: Wizard State Machine
**What:** Use an enum-driven state machine for wizard navigation
**When to use:** For the 4-step wizard flow
**Example:**
```dart
enum ImportStep { upload, preview, confirm, result }

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  ImportStep _currentStep = ImportStep.upload;
  List<CsvRow> _parsedRows = [];
  List<CsvRowValidation> _validations = [];
  int _importedCount = 0;
  
  // Step navigation
  void _goToStep(ImportStep step) => setState(() => _currentStep = step);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildStepIndicator(),  // Step 1/4, 2/4, etc.
          Expanded(child: _buildCurrentStep()),
        ],
      ),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case ImportStep.upload: return _buildUploadStep();
      case ImportStep.preview: return _buildPreviewStep();
      case ImportStep.confirm: return _buildConfirmStep();
      case ImportStep.result: return _buildResultStep();
    }
  }
}
```

### Pattern 3: Per-Row Validation Model
**What:** Typed validation result per CSV row
**When to use:** To power both the preview table and error summary
**Example:**
```dart
class CsvRow {
  final int rowNumber;
  final String nama;
  final String? jabatan;
  final String gerai;
  final String? fotoUrl;
  
  const CsvRow({required this.rowNumber, required this.nama, this.jabatan, required this.gerai, this.fotoUrl});
}

class CsvRowValidation {
  final CsvRow row;
  final List<String> errors;
  final String? resolvedOutletId;
  final String? resolvedOutletName;
  
  bool get isValid => errors.isEmpty;
  
  const CsvRowValidation({required this.row, required this.errors, this.resolvedOutletId, this.resolvedOutletName});
}
```

### Pattern 4: Outlet Resolution (Case-Insensitive)
**What:** Build a lookup map from outlet names to IDs at validation time
**When to use:** Required for CSV-03
**Example:**
```dart
// Pre-fetch outlets (same pattern as admin_employees_screen.dart:92-99)
final outletData = await SupabaseClientFactory.admin
    .from('outlets').select('*').eq('is_active', true).order('name');
final outlets = outletData.map((o) => Outlet.fromJson(o)).toList();

// Build case-insensitive lookup
final outletMap = <String, Outlet>{};
for (final outlet in outlets) {
  outletMap[outlet.name.toLowerCase().trim()] = outlet;
}

// Resolve each row
final csvGerai = row.gerai.toLowerCase().trim();
final outlet = outletMap[csvGerai];
if (outlet == null) {
  errors.add('Outlet "${row.gerai}" tidak ditemukan');
}
```

### Pattern 5: Duplicate Detection (DB + Within-CSV)
**What:** Two-level duplicate check: within CSV file and against existing DB employees
**When to use:** Required for CSV-05
**Example:**
```dart
// 1. Fetch existing employees
final empData = await SupabaseClientFactory.admin
    .from('employees').select('name, home_outlet_id').eq('is_active', true);

// Build existing key set
final existingKeys = <String>{};
for (final e in empData) {
  final key = '${(e['name'] as String).toLowerCase().trim()}|${e['home_outlet_id']}';
  existingKeys.add(key);
}

// 2. Check within-CSV duplicates
final csvKeys = <String>{};
for (final row in rows) {
  final outletId = outletMap[row.gerai.toLowerCase().trim()]?.id;
  if (outletId == null) continue; // outlet error already caught
  
  final key = '${row.nama.toLowerCase().trim()}|$outletId';
  
  if (existingKeys.contains(key)) {
    errors.add('Karyawan "${row.nama}" sudah terdaftar di outlet "${row.gerai}"');
  }
  if (csvKeys.contains(key)) {
    errors.add('Duplikat dalam CSV: "${row.nama}" di outlet "${row.gerai}" muncul lebih dari sekali');
  }
  csvKeys.add(key);
}
```

### Pattern 6: Template Download (Existing share_plus Pattern)
**What:** Generate a CSV template file and share via system share sheet
**When to use:** Upload step "Download Template" button
**Example:**
```dart
// Follow exact pattern from admin_reports_screen.dart:270-280
Future<void> _downloadTemplate() async {
  final buffer = StringBuffer();
  buffer.writeln('nama,jabatan,gerai,foto_url');
  buffer.writeln('Ahmad Fauzi,Kasir,Enakko Sudirman,');
  buffer.writeln('Budi Santoso,Koki,Enakko Margonda,');
  
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/template_import_karyawan.csv');
  await file.writeAsString(buffer.toString());
  
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Template Import Karyawan Enakko',
  );
}
```

### Anti-Patterns to Avoid
- **Server-side CSV processing:** No need — max ~200 employees, client-side parsing is instant. Don't create Edge Functions.
- **Partial import with error rows skipped:** User decision is ALL-OR-NOTHING. Don't implement "import valid rows only" as a fallback.
- **Inline editing in preview table:** Explicitly deferred. Re-upload is the fix path.
- **Building custom CSV parser:** Use the `csv` package. `split(',')` breaks on quoted fields.
- **Using `photo_url` validation with HTTP HEAD:** Too slow, unreliable. Accept any URL string. Display will use `cached_network_image` which handles errors gracefully.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSV parsing | Manual `split(',')` or regex | `csv` package `CsvToListConverter` | Quoted fields, BOM detection, edge cases with commas in names |
| File picking | Custom intent/channel | `file_picker` package | SAF compliance, proper MIME type filtering, cross-Android-version support |
| CSV template sharing | Custom download manager | `share_plus` + `path_provider` | Already in project, proven pattern in `admin_reports_screen.dart` |
| Batch insert | Loop of individual inserts | `SupabaseClientFactory.admin.from('employees').insert(List<Map>)` | Single network call, atomic, proven in `shift_scheduler_screen.dart:670` |

**Key insight:** The CSV *reading* direction (import) is more complex than *writing* (export). The existing `_escapeCsv()` + `StringBuffer` pattern handles export fine, but import needs proper RFC 4180 parsing via the `csv` package to handle BOM, encoding, quoted fields, and edge cases.

## Common Pitfalls

### Pitfall 1: UTF-8 BOM Corruption
**What goes wrong:** Excel on Windows exports CSV with a UTF-8 BOM (3 bytes: `0xEF 0xBB 0xBF`). If not stripped, the first header becomes `\uFEFFnama` instead of `nama`, causing header detection to fail silently.
**Why it happens:** Excel always adds BOM to UTF-8 CSV exports on Windows.
**How to avoid:** Strip BOM before parsing: `if (content.startsWith('\uFEFF')) content = content.substring(1);`
**Warning signs:** First column header never matches, but all other columns work fine.

### Pitfall 2: Case-Sensitive Outlet Matching
**What goes wrong:** CSV has "enakko sudirman" but DB has "Enakko Sudirman". Strict string comparison fails.
**Why it happens:** Admin types outlet name in CSV without matching exact DB capitalization.
**How to avoid:** Always `.toLowerCase().trim()` both sides before comparison. This is explicitly required by CSV-03.
**Warning signs:** Valid outlet names reported as "tidak ditemukan".

### Pitfall 3: Empty Rows at End of CSV
**What goes wrong:** Excel often adds trailing empty rows. Parsing them creates invalid rows with all-empty fields.
**Why it happens:** Excel CSV export includes trailing newlines/empty rows.
**How to avoid:** Filter out rows where all fields are empty/whitespace after parsing.
**Warning signs:** Preview shows extra rows with "missing required field" errors at the bottom.

### Pitfall 4: Duplicate Detection Race Condition
**What goes wrong:** Admin uploads CSV, preview looks good, but between preview and confirm another admin adds the same employee manually. Batch insert fails with 23505 error.
**Why it happens:** Time gap between validation and insert.
**How to avoid:** Wrap batch insert in try/catch. On `PostgrestException` code `23505`, show user-friendly error and prompt re-upload. The existing pattern in `sync_service.dart:56-57` handles this exact code.
**Warning signs:** Confirm step fails unexpectedly after successful preview.

### Pitfall 5: Supabase Batch Insert Payload Structure
**What goes wrong:** Passing inconsistent keys across payload maps causes Supabase to reject the batch. If one row has `photo_url` key and another doesn't, the insert may fail.
**Why it happens:** Optional fields omitted entirely instead of set to null.
**How to avoid:** Every payload map MUST have the same keys. Use `null` for empty optional fields, never omit the key.
**Warning signs:** Batch insert fails with cryptic Supabase error about column mismatch.

### Pitfall 6: File Picker Returns Null Bytes on Cancel
**What goes wrong:** `FilePicker.platform.pickFiles()` returns null when user cancels. Code that assumes non-null result crashes.
**Why it happens:** User taps back or cancels the file picker dialog.
**How to avoid:** Always null-check `result` and `result.files.single.bytes`. Guard with early return.
**Warning signs:** Null pointer exception on cancel.

## Code Examples

Verified patterns from existing codebase:

### Batch Insert (from shift_scheduler_screen.dart:669-671)
```dart
// Existing pattern — pass List<Map> to .insert()
if (entriesData.isNotEmpty) {
  await SupabaseClientFactory.admin.from('schedule_entries').insert(entriesData);
  debugPrint('Bulk inserted ${entriesData.length} entries');
}
```

### Employee Insert Payload (from admin_employees_screen.dart:1353-1366)
```dart
final payload = {
  'name': _nameCtrl.text.trim(),
  'position': _positionCtrl.text.trim().isEmpty ? null : _positionCtrl.text.trim(),
  'employee_code': _empCodeCtrl.text.trim().isEmpty ? null : _empCodeCtrl.text.trim(),
  'home_outlet_id': _selectedOutletId,
  'is_active': true,  // CSV imports always active (not archived)
};
await SupabaseClientFactory.admin.from('employees').insert(payload);
```

### CSV Export / Share Pattern (from admin_reports_screen.dart:270-280)
```dart
final dir = await getTemporaryDirectory();
final file = File('${dir.path}/$filename');
await file.writeAsString(buffer.toString());
await Share.shareXFiles(
  [XFile(file.path, mimeType: 'text/csv')],
  subject: 'Template Import Karyawan Enakko',
);
```

### Duplicate Error Handling (from sync_service.dart:56-58)
```dart
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Duplicate — already exists, handle gracefully
  }
}
```

### Outlet Fetch (from admin_employees_screen.dart:92-99)
```dart
var outFilter = SupabaseClientFactory.admin
    .from('outlets')
    .select('*')
    .eq('is_active', true);
final outData = await outFilter.order('name');
final outlets = outData.map((o) => Outlet.fromJson(o)).toList();
```

### GoRouter Admin Route (from app.dart:104-129)
```dart
ShellRoute(
  builder: (_, __, child) => AdminShell(child: child),
  routes: [
    // ... existing routes ...
    GoRoute(
      path: '/admin/csv-import',
      builder: (_, __) => const CsvImportScreen(),
    ),
  ],
),
```

### Navigation Button in Summary Strip (from admin_employees_screen.dart:298-316)
```dart
// Existing archive button pattern — add CSV import button similarly
GestureDetector(
  onTap: () => context.push('/admin/csv-import'),
  child: Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: AppColors.textMuted.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.textMuted.withOpacity(0.2)),
    ),
    child: const Tooltip(
      message: 'Import CSV',
      child: Icon(Icons.upload_file_outlined, size: 18, color: AppColors.textSecondary),
    ),
  ),
),
```

### Toast Notifications (from app_toast.dart)
```dart
AppToast.success(context, '${count} karyawan berhasil diimpor');
AppToast.error(context, 'Gagal mengimpor karyawan');
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `csv: ^5.x` | `csv: ^6.0.0` | 2024 | API is stable, `CsvToListConverter` and `CsvCodec` unchanged |
| `file_picker: ^5.x` | `file_picker: ^8.1.0` | 2024-2025 | v6+ uses SAF properly on Android 10+, result model changed |
| Manual BOM stripping | `csv` handles BOM natively with `shouldParseNumbers: false` | Recent | Still recommend explicit BOM strip for safety |

**Deprecated/outdated:**
- `file_picker` v5.x: Old permission model, doesn't use SAF properly on newer Android. v8.x is current.
- `csvParser` from `dart:io`: Doesn't exist. Use `csv` package.

## Open Questions

1. **Employee code generation for CSV imports**
   - What we know: The existing employee sheet has an `employee_code` field that's manually entered. CSV template doesn't include `employee_code`.
   - What's unclear: Should CSV-imported employees get auto-generated codes, or leave null (to be filled later)?
   - Recommendation: Leave `employee_code` as null for CSV imports. Admin can edit individually later. This matches the current manual-add behavior where it's optional.

2. **photo_url validation depth**
   - What we know: `foto_url` column is optional. The app uses `cached_network_image` which handles broken URLs gracefully.
   - What's unclear: Should we validate URL format (starts with `http://` or `https://`)?
   - Recommendation: Do basic format validation (must start with `http://` or `https://` if non-empty). Don't HTTP HEAD — too slow and unreliable.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | `analysis_options.yaml` (exists) |
| Quick run command | `flutter test test/services/csv_import_service_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CSV-01 | Parse CSV bytes into CsvRow list | unit | `flutter test test/services/csv_import_service_test.dart -x` | ❌ Wave 0 |
| CSV-02 | Map CSV columns (nama, jabatan, gerai, foto_url) to payload | unit | `flutter test test/services/csv_import_service_test.dart -x` | ❌ Wave 0 |
| CSV-03 | Resolve outlet name → UUID case-insensitively | unit | `flutter test test/services/csv_import_service_test.dart -x` | ❌ Wave 0 |
| CSV-04 | Preview shows all parsed rows with validation | widget | manual-only — requires mounted widget with Supabase mock | N/A |
| CSV-05 | Detect duplicates (DB + within-CSV) | unit | `flutter test test/services/csv_import_service_test.dart -x` | ❌ Wave 0 |
| CSV-06 | Per-row validation errors aggregated | unit | `flutter test test/services/csv_import_service_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/csv_import_service_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/csv_import_service_test.dart` — covers CSV-01, CSV-02, CSV-03, CSV-05, CSV-06 (parsing, validation, duplicate detection)
- [ ] `test/models/csv_import_result_test.dart` — covers CsvRow / CsvRowValidation model correctness
- [ ] Framework install: none needed — `flutter_test` already in dev_dependencies

## Sources

### Primary (HIGH confidence)
- **Existing codebase** — `shift_scheduler_screen.dart:669-671` (batch insert), `admin_reports_screen.dart:218-288` (CSV export/share), `sync_service.dart:56-58` (duplicate handling), `admin_employees_screen.dart:1345-1366` (employee payload)
- **Existing models** — `employee.dart` (Employee model with all fields), `outlet.dart` (Outlet model)
- **Existing router** — `app.dart:104-129` (ShellRoute admin pattern)

### Secondary (MEDIUM confidence)
- **`csv` package** — pub.dev dart `csv` ^6.0.0, RFC 4180 compliant parser. API: `CsvToListConverter().convert(String)` returns `List<List<dynamic>>`.
- **`file_picker` package** — pub.dev `file_picker` ^8.1.0. API: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])` returns `FilePickerResult?` with `PlatformFile` containing `bytes` (Uint8List?).
- **Project SUMMARY.md research** — pre-validated csv ^6.0.0 + file_picker ^8.1.0 as the stack for this phase.

### Tertiary (LOW confidence)
- None — all patterns verified against existing codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages pre-selected in project research, versions verified
- Architecture: HIGH — all patterns exist in codebase, service+screen separation follows project convention
- Pitfalls: HIGH — BOM/encoding, case-sensitivity, empty rows are well-known CSV parsing issues; codebase already handles Supabase errors
- Validation: HIGH — unit-testable service layer with pure functions for parse/validate

**Research date:** 2026-03-11
**Valid until:** 2026-04-11 (stable domain, no rapidly changing dependencies)

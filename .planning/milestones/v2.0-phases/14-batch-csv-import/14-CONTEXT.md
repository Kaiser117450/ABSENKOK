# Phase 14: Batch CSV Import - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Admin can onboard multiple karyawan at once via CSV file upload. The system validates all rows, shows a preview with per-row status, and batch-inserts valid employees into the database. This covers upload, parse, validate, preview, confirm, and result — the full import pipeline.

</domain>

<decisions>
## Implementation Decisions

### Upload & Preview Flow
- Separate full screen at `/admin/csv-import` (not dialog or tab)
- Navigation: button in the existing action row alongside Jadwal, Refresh, Arsip
- Step-by-step wizard flow: **Upload → Preview → Confirm → Result**
- Preview displays a data table with columns: No, Nama, Jabatan, Gerai, Status (valid/error icon per row)

### Validation & Error UX
- Error display: both inline icons per row in Status column + expandable error summary panel below table
- **All-or-nothing import**: all rows must be valid before import proceeds — no partial import
- If errors found, admin must re-upload a corrected CSV (no inline editing in preview table)
- Duplicate detection: same nama + same gerai = duplicate (checked against existing DB employees AND within the CSV itself)

### CSV Format & Template
- App provides a "Download Template" button on the upload step
- Column headers in Indonesian: `nama`, `jabatan`, `gerai`, `foto_url`
- Comma separator only (standard CSV)
- `nama` = required (min 3 chars), `jabatan` = optional, `gerai` = required (must match existing outlet), `foto_url` = optional (external URL)
- NFC UID is NOT in CSV (assigned later via physical card tap)

### Result Screen
- Success summary screen showing: total count imported + list of employee names grouped by outlet
- This is the final step of the wizard before admin navigates away

### Claude's Discretion
- Exact styling of wizard steps (Stepper widget or custom)
- Upload area design (drag-and-drop zone or simple file picker button)
- Loading/progress indicator during batch insert
- Empty template content (sample rows or headers only)
- Error message wording for specific validation failures
- Whether to show a "back to employees" button or auto-navigate after result

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Batch insert pattern**: `shift_scheduler_screen.dart` uses `.insert(List<Map>)` for bulk schedule_entries
- **Supabase duplicate handling**: `sync_service.dart` catches PostgrestException code 23505
- **CSV string generation**: `admin_reports_screen.dart` has `_exportCsv()` pattern (reference for format)
- **share_plus**: already installed for file operations (template download)

### Established Patterns
- Employee payload: `{name, position, employee_code, home_outlet_id, is_active}` via `SupabaseClientFactory.admin`
- Outlet resolution: `.from('outlets').select('*').eq('is_active', true).order('name')`
- Admin screens: GoRouter ShellRoute with AdminShell wrapper
- Photo URLs: external URL string stored in `photo_url` field, rendered via `cached_network_image`

### Integration Points
- **Route**: Add `/admin/csv-import` to GoRouter admin ShellRoute in `app.dart`
- **Navigation**: Add CSV import button to action row in `admin_employees_screen.dart` (summary strip)
- **Dependencies**: Need to add `file_picker` and `csv` packages to pubspec.yaml
- **Employee insert**: Same Supabase `.from('employees').insert(payload)` as _EmployeeSheet

</code_context>

<specifics>
## Specific Ideas

- Template CSV should have Indonesian headers matching the app language
- Wizard flow mimics common onboarding patterns (step indicator at top)
- Error summary panel should be collapsible so admin can focus on the table
- Outlet name matching must be case-insensitive per CSV-03

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-batch-csv-import*
*Context gathered: 2026-03-11*

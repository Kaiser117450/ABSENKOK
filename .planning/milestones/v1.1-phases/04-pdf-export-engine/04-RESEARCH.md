# Phase 4: PDF Export Engine - Research

**Researched:** 2026-03-02
**Domain:** Flutter PDF generation (`pdf` 3.11.3 + `printing` 5.14.2) + `share_plus` 10.1.4
**Confidence:** HIGH

---

## Summary

Phase 4 adds a branded PDF attendance report to the existing Admin Reports screen. The project
already has `pdf: ^3.10.8` (resolved to 3.11.3) and `printing: ^5.13.4` (resolved to 5.14.2)
in `pubspec.yaml` — no new packages are needed. The existing `pdf_service.dart` (for schedule
PDFs) demonstrates the exact API: `pw.Document`, `pw.Page`, `pw.Table`, `PdfColor.fromHex`,
`pw.Font.helvetica()`, `pw.Font.helveticaBold()`, save to temp dir, then `Share.shareXFiles()`.
This pattern is the template for the new `pdf_report_service.dart`.

The primary input data comes from `_computeDailySummaries()` in `admin_reports_screen.dart`,
which returns `List<_DailySummary>`. Each `_DailySummary` carries: `employee`, `outlet`,
`dateLabel`, `firstMasuk`, `lastPulang`, `workDuration`, `totalBreak`, `scanCount`, `status`
(normal/sakit/izin/belumPulang), and `statusNotes`. The service needs to aggregate these
summaries by employee to produce per-employee statistics (hadir count, avg masuk, avg pulang,
total hours, sakit count) and global insight card metrics.

The key complexity is that `_DailySummary` is a private class inside `admin_reports_screen.dart`.
The planner must decide between extracting it to a shared model file or passing already-computed
aggregates into the service. Extracting to `lib/models/daily_summary.dart` is the clean approach
and enables reuse in Phase 5 (CSV Rekap Harian export).

**Primary recommendation:** Create `lib/services/pdf_report_service.dart` as a static-method
service following the exact same pattern as the existing `lib/services/pdf_service.dart`. Extract
`_DailySummary` and `DailySummaryStatus` to `lib/models/daily_summary.dart` to make them
accessible to the service. Add `_exportPdf()` method to `_AdminReportsScreenState` and place
the "Export PDF" button next to the existing "Export CSV" button in the Per Scan tab bar area.

---

## Standard Stack

### Core (already installed — zero new dependencies needed)

| Library | Resolved Version | Purpose | Status |
|---------|-----------------|---------|--------|
| `pdf` | 3.11.3 | PDF document construction, layout, tables | Already in pubspec |
| `printing` | 5.14.2 | PDF rendering, rasterization helpers | Already in pubspec |
| `share_plus` | 10.1.4 | OS share sheet for file sharing | Already in pubspec |
| `path_provider` | 2.1.5+ | Temp directory for saving PDF before share | Already in pubspec |
| `intl` | 0.19.0 | Date formatting for Indonesian locale | Already in pubspec |

**Installation:** None required. All dependencies already resolved.

### Supporting (already in project)

| Library | Purpose | How Used in Phase 4 |
|---------|---------|---------------------|
| `dart:io` | File read/write | `File(path).writeAsBytes(await pdf.save())` |
| `dart:typed_data` | Byte handling | `Uint8List` for image assets |
| `flutter/services.dart` | Asset loading | `rootBundle.load()` for logo PNG |

### Alternatives Considered

| Standard Choice | Alternative | Why Standard Wins |
|-----------------|-------------|------------------|
| `pdf` package | `syncfusion_flutter_pdf` | `pdf` already installed; Syncfusion requires license |
| `pw.Font.helvetica()` | Custom TTF font | Helvetica is built-in, no asset needed; custom TTF requires embedding |
| `Share.shareXFiles()` | `open_file` package | `share_plus` already used for CSV export; consistent UX |

---

## Architecture Patterns

### Recommended Project Structure (additions only)

```
lib/
├── models/
│   └── daily_summary.dart    # Extract _DailySummary + DailySummaryStatus here (NEW)
├── services/
│   ├── pdf_service.dart      # Existing — schedule PDF, LEAVE INTACT
│   └── pdf_report_service.dart  # NEW — attendance report PDF
└── screens/
    └── admin/
        └── admin_reports_screen.dart  # Add _exportPdf(), Export PDF button, import daily_summary.dart
```

### Pattern 1: Static Service Class (copy existing pdf_service.dart pattern)

**What:** Single static method `generateAttendanceReport(...)` that receives all needed data,
builds the PDF in memory, saves to temp dir, and calls `Share.shareXFiles()`.

**When to use:** All PDF generation in this project — keeps business logic out of widgets.

```dart
// Source: existing lib/services/pdf_service.dart (working reference)
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/daily_summary.dart';

class PdfReportService {
  static Future<void> generateAttendanceReport({
    required List<DailySummary> summaries,
    required DateTime startDate,
    required DateTime endDate,
    required String outletName,
  }) async {
    final pdf = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    // Compute aggregates
    final stats = _computeStats(summaries);

    pdf.addPage(_buildSummaryPage(stats, startDate, endDate, outletName, regular, bold));
    for (final chunk in _chunkEmployeeRows(stats.employeeRows, 25)) {
      pdf.addPage(_buildTablePage(chunk, regular, bold));
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'laporan_absensi_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Laporan Absensi Enakko - $outletName',
    );
  }
}
```

### Pattern 2: Aggregate-First, Then Build

**What:** Compute all stats from `List<DailySummary>` first into a plain record/struct, then
pass the struct to page-building methods. Never compute stats inside page builders.

**Why:** Page builders (`pw.Page build: (context)`) are called inside the PDF render loop.
Computing stats inside them causes logic to execute multiple times.

```dart
// Aggregate record
typedef _ReportStats = ({
  int totalHadir,
  double attendanceRate,
  Duration avgWorkHours,
  int totalSakit,
  int totalScan,
  List<_EmployeeRow> employeeRows,
});

// _EmployeeRow — one per unique employee across all dates
typedef _EmployeeRow = ({
  String name,
  int hadirCount,
  DateTime? avgMasuk,   // null if no data
  DateTime? avgPulang,  // null if no data
  Duration totalKerja,
  int sakitCount,
});
```

### Pattern 3: Chunked Table Pages

**What:** Split employee rows into pages of max 25 rows. Each chunk becomes a `pw.MultiPage`
or separate `pw.Page`.

```dart
// Source: derived from existing pdf_service.dart table pattern
List<List<_EmployeeRow>> _chunkEmployeeRows(List<_EmployeeRow> rows, int pageSize) {
  final chunks = <List<_EmployeeRow>>[];
  for (var i = 0; i < rows.length; i += pageSize) {
    chunks.add(rows.sublist(i, i + pageSize > rows.length ? rows.length : i + pageSize));
  }
  return chunks;
}
```

### Pattern 4: Export Button alongside CSV button

**What:** Add a second `TextButton.icon` immediately after the existing CSV button, same row.
Mirror `_exporting` with `_exportingPdf` boolean state.

```dart
// In _AdminReportsScreenState — existing CSV button area (line ~641):
Row(
  children: [
    Text('${_rows.length} data scan', ...),
    const Spacer(),
    TextButton.icon(
      onPressed: _exporting ? null : _exportCsv,
      // ... existing CSV button
    ),
    const SizedBox(width: 8),
    TextButton.icon(
      onPressed: _exportingPdf ? null : _exportPdf,
      icon: _exportingPdf
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(...))
          : const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
      label: Text(
        _exportingPdf ? 'Generating...' : 'Export PDF',
        style: const TextStyle(color: AppColors.primary, fontSize: 13),
      ),
    ),
  ],
)
```

### Anti-Patterns to Avoid

- **Computing stats inside `pw.Page build: (context)`:** Build callbacks execute per-render; stats inflate. Always pre-compute.
- **Using `pw.MultiPage` for the table:** MultiPage handles automatic page breaks but makes custom headers/footers per-page harder to control. Use multiple explicit `pw.Page` objects with 25-row chunks for full control.
- **Embedding a Google Font in the PDF:** Google Fonts require downloading and embedding TTF bytes via `rootBundle`. Helvetica is built-in and zero-overhead. Use Helvetica unless branding requires custom font.
- **Calling `_computeDailySummaries()` inside `_exportPdf()`:** The screen already has computed `_dailyRows`; re-run `_computeDailySummaries()` to get summaries (it's pure/deterministic), then pass to service. Do NOT re-fetch from Supabase.
- **Sharing before `await pdf.save()`:** `pdf.save()` is async and must complete before `shareXFiles`.
- **Logo as network URL in PDF:** The `pdf` package cannot load network images in Android at runtime. Use `assets/icon.png` via `rootBundle.load()` + `pw.MemoryImage`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Table layout with borders | Manual border painting | `pw.Table` with `pw.TableBorder.all()` | Already demonstrated in `pdf_service.dart`; handles column widths, padding, row decoration |
| Page numbering footer | Manual counter variable | `pw.MultiPage` `footer` callback OR footer in each `pw.Page` with explicit page/total tracking | Fragile to build manually; `pw.Page` context has no built-in counter; track manually as page index |
| Alternating row colors | Conditional logic per row | `pw.TableRow(decoration: pw.BoxDecoration(color: i.isEven ? ... : ...))` | Already shown in `pdf_service.dart` |
| Temp file handling | Custom path logic | `getTemporaryDirectory()` from `path_provider` | Cross-platform safe temp dir |
| Share sheet + MIME type | Custom intent | `Share.shareXFiles([XFile(path, mimeType: 'application/pdf')])` | Already used for CSV; mimeType ensures Android opens PDF viewer |

**Key insight:** The existing `pdf_service.dart` is a complete, working reference for every PDF
construction primitive needed in this phase. Read it first before building anything new.

---

## Common Pitfalls

### Pitfall 1: `_DailySummary` is private — service cannot access it
**What goes wrong:** `PdfReportService` lives in `lib/services/` but `_DailySummary` is a
private class inside `admin_reports_screen.dart`. Dart private classes (underscore prefix)
are file-scoped — importing the screen file does not expose them.
**Why it happens:** The class was defined private because it was screen-internal state.
**How to avoid:** Extract `_DailySummary` → `DailySummary` and `DailySummaryStatus` to
`lib/models/daily_summary.dart`. Update `admin_reports_screen.dart` to import and use the model.
This is a prerequisite for the service to compile.
**Warning signs:** `The name '_DailySummary' isn't a type` compiler error.

### Pitfall 2: Logo asset not in PDF-accessible format
**What goes wrong:** `assets/icon.png` is currently the only image asset. Loading it for PDF
requires `rootBundle.load('assets/icon.png')` which returns `ByteData`. Must convert to
`Uint8List` and wrap in `pw.MemoryImage`.
**Why it happens:** The `pdf` package requires images as `pw.ImageProvider`, not `Image.asset`.
**How to avoid:**
```dart
// Source: pdf package documentation pattern
final logoData = await rootBundle.load('assets/icon.png');
final logoBytes = logoData.buffer.asUint8List();
final logoImage = pw.MemoryImage(logoBytes);
// Then in page: pw.Image(logoImage, width: 48, height: 48)
```
**Warning signs:** `Null check operator used on a null value` when accessing image data.

### Pitfall 3: Aggregate math — avg masuk/pulang across multiple days
**What goes wrong:** Averaging `DateTime` values naively (summing milliseconds then dividing)
works, but the result is a `DateTime` on the epoch date. For display, extract only HH:mm.
**Why it happens:** Attendances across different calendar dates have different epoch timestamps.
**How to avoid:** Average only the time-of-day in minutes: `masuk.hour * 60 + masuk.minute`,
then convert back to `HH:mm` string. Never average full DateTime for display.
```dart
// Correct: average time-of-day only
int totalMinutes = masukTimes.fold(0, (sum, dt) => sum + dt.hour * 60 + dt.minute);
int avgMinutes = totalMinutes ~/ masukTimes.length;
String avgMasukStr = '${(avgMinutes ~/ 60).toString().padLeft(2,'0')}:${(avgMinutes % 60).toString().padLeft(2,'0')}';
```

### Pitfall 4: `_exportPdf()` called when `_dailyRows` is empty
**What goes wrong:** If user taps "Export PDF" before loading data, `_computeDailySummaries()`
returns an empty list and the PDF contains no employee table — confusing the user.
**Why it happens:** No guard on the export button.
**How to avoid:** Disable button when `!_hasLoaded || _dailyRows.isEmpty`. Show a snackbar
"Load data terlebih dahulu" if called prematurely.

### Pitfall 5: PDF generation blocking the UI thread
**What goes wrong:** For 30-day, 14-employee data, PDF generation with table rendering can take
2-4 seconds. If run on the main isolate, the UI freezes.
**Why it happens:** `pw.Document.save()` is CPU-intensive (layout engine + compression).
**How to avoid:** Wrap the entire generation in `compute()` or run in an isolate. The existing
`pdf_service.dart` does NOT use `compute()` — this is a known gap. For 14 employees × 30 days
= 420 summaries, generation should still be under 5 seconds without isolate, but keep in mind
the `_exportingPdf` loading indicator must be shown immediately before starting async work.
`setState(() => _exportingPdf = true)` BEFORE the `await`.

### Pitfall 6: `Share.shareXFiles` on Android requires file in accessible path
**What goes wrong:** Sharing a file from the app's private cache may require a FileProvider on
some Android versions.
**Why it happens:** Android file access restrictions.
**How to avoid:** Use `getTemporaryDirectory()` (already used in `pdf_service.dart`). This
resolves to a path that `share_plus` handles correctly on Android with its own FileProvider
configuration. Do not use app-private data directories.

---

## Code Examples

Verified patterns from the existing codebase (lib/services/pdf_service.dart):

### Header Block with Logo Placeholder
```dart
// Source: lib/services/pdf_service.dart lines 36-90
pw.Row(
  children: [
    pw.Container(
      width: 50, height: 50,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('DC2626'),  // AppColors.primary
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text('E', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ),
    ),
    pw.SizedBox(width: 16),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Ayam Guling Enakko', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('DC2626'))),
        pw.Text('Laporan Absensi', style: pw.TextStyle(fontSize: 14, color: PdfColor.fromHex('6B7280'))),
        pw.Text('$rangeStr · $outletName', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('9CA3AF'))),
      ],
    ),
  ],
)
```

### Table with Alternating Row Colors
```dart
// Source: lib/services/pdf_service.dart lines 114-236 (adapted)
pw.Table(
  border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
  columnWidths: {
    0: const pw.FixedColumnWidth(20),   // No
    1: const pw.FixedColumnWidth(100),  // Nama
    2: const pw.FixedColumnWidth(40),   // Hadir
    3: const pw.FixedColumnWidth(50),   // Avg Masuk
    4: const pw.FixedColumnWidth(50),   // Avg Pulang
    5: const pw.FixedColumnWidth(55),   // Total Jam
    6: const pw.FixedColumnWidth(40),   // Sakit
  },
  children: [
    // Header row — red background
    pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('FEE2E2')),
      children: ['No','Nama','Hadir','Avg Masuk','Avg Pulang','Total Jam','Sakit']
          .map((h) => _cell(h, bold, isHeader: true))
          .toList(),
    ),
    // Data rows — alternating
    ...employeeRows.asMap().entries.map((e) {
      final i = e.key;
      final row = e.value;
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : PdfColor.fromHex('F9FAFB'),
        ),
        children: [/* row cells */],
      );
    }),
  ],
)
```

### Insight Card (2x2 Grid)
```dart
// Pattern: pw.Row with two pw.Expanded containers for 2-column layout
pw.Row(
  children: [
    pw.Expanded(child: _insightCard('Total Hadir', '$totalHadir hari', PdfColor.fromHex('16A34A'), bold, regular)),
    pw.SizedBox(width: 8),
    pw.Expanded(child: _insightCard('Tingkat Hadir', '${attendanceRate.toStringAsFixed(1)}%', PdfColor.fromHex('16A34A'), bold, regular)),
  ],
)
// Two rows for 2x2
pw.SizedBox(height: 8),
pw.Row(
  children: [
    pw.Expanded(child: _insightCard('Rata-rata Jam Kerja', avgWorkStr, PdfColor.fromHex('1D4ED8'), bold, regular)),
    pw.SizedBox(width: 8),
    pw.Expanded(child: _insightCard('Tidak Hadir', '$totalSakit kali', PdfColor.fromHex('DC2626'), bold, regular)),
  ],
)

static pw.Widget _insightCard(String label, String value, PdfColor accentColor, pw.Font bold, pw.Font regular) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColor.fromHex('E5E7EB'), width: 0.5),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColor.fromHex('6B7280'))),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 16, color: accentColor)),
      ],
    ),
  );
}
```

### Save and Share
```dart
// Source: lib/services/pdf_service.dart lines 257-268
final directory = await getTemporaryDirectory();
final fileName = 'laporan_absensi_${DateFormat('yyyyMMdd').format(startDate)}.pdf';
final file = File('${directory.path}/$fileName');
await file.writeAsBytes(await pdf.save());

await Share.shareXFiles(
  [XFile(file.path, mimeType: 'application/pdf')],
  subject: 'Laporan Absensi Enakko',
);
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `printing.layoutPdf()` for sharing | `pdf.save()` → `Share.shareXFiles()` | Direct file share is simpler for mobile; `printing` is for print dialogs |
| Embedding custom fonts | Built-in Helvetica/Courier | Sufficient for data reports; custom TTF requires ~500KB asset |
| `MultiPage` for automatic pagination | Multiple explicit `pw.Page` objects | More control for fixed 25-row chunks per page |

**Key version note:** `pdf` 3.11.x (current) uses `pw.Font.helvetica()` without arguments.
Earlier `pdf` 2.x used different font registration. The existing `pdf_service.dart` is already
on 3.11.x so its patterns are directly applicable.

---

## Open Questions

1. **Logo asset for PDF header**
   - What we know: `assets/icon.png` exists and is the app launcher icon
   - What's unclear: Is the icon appropriate as a brand logo in the PDF header, or should `assets/images/logo_enakko.png` be created first (that asset is referenced in Phase 6 / REQ-M4-02 but not yet created)?
   - Recommendation: Use a red "E" box placeholder (identical to existing `pdf_service.dart` pattern) for Phase 4. The logo asset will be wired in Phase 6. This unblocks PDF export without waiting for Phase 6.

2. **Export button placement — which tab triggers PDF export?**
   - What we know: Current CSV button is only in the Per Scan tab bar area. The PDF should export the Rekap Harian summary (per-employee aggregate), not the raw scan list.
   - What's unclear: Should the PDF button appear in the Rekap Harian tab header specifically, or alongside the CSV button in the Per Scan tab?
   - Recommendation: Place the PDF button in the Rekap Harian tab header row (mirror the CSV button placement) and guard with `_dailyRows.isNotEmpty`. This makes data source clear to the user.

3. **`_DailySummary` model extraction scope**
   - What we know: `_DailySummary` is currently private. Phase 5 (CSV Rekap) also needs it.
   - What's unclear: Should extraction happen in Phase 4 or Phase 5?
   - Recommendation: Extract in Phase 4 (it's a prerequisite for the PDF service). Phase 5 then gets it for free.

---

## Key Data Model Reference

### Existing `_DailySummary` (to be extracted to `lib/models/daily_summary.dart`)

```dart
// Source: lib/screens/admin/admin_reports_screen.dart lines 787-810
enum DailySummaryStatus { normal, sakit, izin, belumPulang }

class DailySummary {  // rename: remove underscore prefix
  final String dateLabel;        // "YYYY-MM-DD"
  final Employee? employee;
  final Outlet? outlet;
  final DateTime? firstMasuk;
  final DateTime? lastPulang;
  final Duration? workDuration;
  final Duration totalBreak;
  final int scanCount;
  final DailySummaryStatus status;
  final String? statusNotes;
}
```

### Per-Employee Aggregation Logic (for service to implement)

```dart
// Group summaries by employee, then compute:
// - hadirCount: summaries where status == normal AND firstMasuk != null
// - sakitCount: summaries where status == sakit
// - avgMasuk:   average firstMasuk time-of-day (minutes) across hadir days
// - avgPulang:  average lastPulang time-of-day across hadir days with lastPulang != null
// - totalKerja: sum of workDuration across all hadir days

// Global stats (from all summaries):
// - totalHadir     = count of normal-status rows with firstMasuk != null
// - totalDays      = distinct date labels count
// - totalEmployees = distinct employee IDs count
// - attendanceRate = totalHadir / (totalDays * totalEmployees) * 100
// - avgWorkHours   = sum(workDuration) / totalHadir  (among days with workDuration != null)
// - totalSakit     = count of rows where status == sakit
// - totalScan      = sum(scanCount) across all summaries
```

---

## Sources

### Primary (HIGH confidence)
- `lib/services/pdf_service.dart` — Direct working reference for all `pdf` 3.11.x patterns used in this project
- `lib/screens/admin/admin_reports_screen.dart` — Source of `_DailySummary`, `DailySummaryStatus`, `_computeDailySummaries()`, `_exportCsv()` pattern, export button placement context
- `pubspec.yaml` + `pubspec.lock` — Confirmed `pdf: 3.11.3`, `printing: 5.14.2`, `share_plus: 10.1.4` already installed
- `lib/core/theme.dart` — Brand colors (`DC2626` primary red, `F59E0B` accent amber, `16A34A` success green)

### Secondary (MEDIUM confidence)
- `pdf` package pub.dev API — `pw.Table`, `pw.TableBorder`, `pw.MultiPage`, `pw.MemoryImage`, `pw.Font.helvetica()` APIs verified as stable in 3.x series

### Tertiary (LOW confidence — not independently verified)
- Performance estimate "< 5 seconds for 14 employees × 30 days" — Based on existing `pdf_service.dart` schedule table performance which handles similar data volume. Actual timing depends on device.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages already installed and in use in the project
- Architecture: HIGH — existing `pdf_service.dart` provides a proven template; no speculation
- Pitfalls: HIGH — identified from direct code analysis of current implementation
- Data model: HIGH — read directly from `admin_reports_screen.dart` source

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable packages, internal codebase)

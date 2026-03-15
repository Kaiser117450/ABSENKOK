# Testing Patterns

**Analysis Date:** 2024-12-20

## Test Framework

**Runner:**
- `flutter_test` (Flutter SDK built-in)
- Version: SDK-bundled (no explicit version in pubspec.yaml)
- Config: No explicit test configuration file (uses Flutter defaults)

**Assertion Library:**
- `flutter_test` built-in `expect()` assertions
- Matchers: `isTrue`, `isEmpty`, `isA<Type>()`, direct equality

**Run Commands:**
```bash
flutter test                  # Run all tests
flutter test --watch          # Watch mode (not explicitly used, but available)
flutter test --coverage       # Generate coverage (no coverage setup detected)
```

## Test File Organization

**Location:**
- Tests mirror source structure: `test/` directory parallels `lib/`
- Pattern: Co-located by feature area

**Naming:**
- Unit tests: `{feature}_test.dart` (e.g., `shift_schedule_test.dart`, `pdf_service_color_test.dart`)
- Widget tests: `{widget}_widget_test.dart` (e.g., `overlay_pill_widget_test.dart`)
- Screen tests: `{screen}_test.dart` (e.g., `rekap_harian_test.dart`)

**Structure:**
```
test/
├── widget_test.dart                          # Placeholder for default Flutter test
├── models/
│   ├── overlay_pill_state_test.dart         # Model serialization tests
│   └── shift_schedule_test.dart             # Schedule model tests
├── services/
│   ├── pdf_report_service_test.dart         # Service logic tests
│   └── pdf_service_color_test.dart          # PDF color mapping tests
├── screens/
│   └── admin/
│       └── rekap_harian_test.dart           # Screen-level tests
└── widgets/
    └── overlay_pill_widget_test.dart        # Widget rendering tests
```

## Test Structure

**Suite Organization:**
```dart
// test/models/shift_schedule_test.dart
void main() {
  group('ShiftSlot factories', () {
    test('pagi shift has correct name and time range', () {
      final pagi = ShiftSlot.pagi();
      expect(pagi.name, 'Pagi');
      expect(pagi.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(pagi.endTime, const TimeOfDay(hour: 17, minute: 0));
    });

    test('siang shift has correct name and time range', () {
      final siang = ShiftSlot.siang();
      expect(siang.name, 'Siang');
      expect(siang.startTime, const TimeOfDay(hour: 12, minute: 0));
      expect(siang.endTime, const TimeOfDay(hour: 20, minute: 0));
    });
  });

  group('ScheduleEntry serialization', () {
    test('toJson → fromJson round-trips for normal entry', () {
      final emp = _makeEmployee('emp-1', 'Alice');
      final original = ScheduleEntry.fromEmployee(
        id: 'entry-1',
        date: DateTime(2024, 3, 4),
        employee: emp,
        shift: ShiftSlot.pagi(),
      );

      final json = original.toJson();
      final restored = ScheduleEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.employeeId, original.employeeId);
      expect(restored.displayName, original.displayName);
    });
  });
}
```

**Patterns:**
- `group()` for logical test suites (by feature or method)
- `test()` for individual test cases
- Setup helpers: private factory functions like `_makeEmployee()`, `_makeSummary()`
- No explicit `setUp()` or `tearDown()` in model tests (stateless)
- Widget tests use `setUp()` and `tearDown()` for stream/controller cleanup

## Test Helpers

**Factory Functions:**
```dart
// test/models/shift_schedule_test.dart
Employee _makeEmployee(String id, String name) => Employee(
  id: id,
  name: name,
  isActive: true,
  createdAt: '2024-01-01',
  updatedAt: '2024-01-01',
);

OutletSchedule _makeSchedule({
  String id = 'sched-1',
  String outletId = 'outlet-1',
  DateTime? start,
  DateTime? end,
  List<ScheduleEntry>? entries,
  DateTime? syncedAt,
}) {
  return OutletSchedule(
    id: id,
    outletId: outletId,
    startDate: start ?? DateTime(2024, 3, 4),
    endDate: end ?? DateTime(2024, 3, 10),
    template: ShiftTemplate.standard(outletId),
    entries: entries ?? [],
    createdAt: DateTime(2024, 3, 1),
    syncedAt: syncedAt,
  );
}
```

**Test-Specific Methods:**
```dart
// test/services/pdf_report_service_test.dart
final stats = PdfReportService.computeStatsForTest([]);
// Production code exposes test helpers via static methods suffixed with "ForTest"

// test/services/pdf_service_color_test.dart
final color = PdfService.statusTextColorForTest('Sakit');
final color = PdfService.typeTextColorForTest('Masuk');
```

## Widget Testing

**Pattern:**
```dart
// test/widgets/overlay_pill_widget_test.dart
void main() {
  group('KioskOverlayUI', () {
    late StreamController<String> stream;

    setUp(() {
      stream = StreamController<String>.broadcast();
    });

    tearDown(() async {
      await stream.close();
    });

    Future<void> pumpOverlay(
      WidgetTester tester, {
      Color background = Colors.white,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: background,
            child: KioskOverlayUI(
              dataStream: stream.stream,
              autoCollapseDelay: const Duration(hours: 1),
              clockTick: const Duration(hours: 1),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'idle payload renders outlet time and attendance accent indicator',
      (tester) async {
        await pumpOverlay(tester);

        stream.add(
          _payload(
            mode: 'idle',
            outlet: 'Gerai Braga',
            time: '09:30',
            attendanceType: 'pulang',
            accentHex: '#6B7280',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        final outlet = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-outlet')),
        );
        final attendance = tester.widget<Text>(
          find.byKey(const Key('overlay-pill-attendance')),
        );

        expect(outlet.data, 'Gerai Braga');
        // ... additional assertions
      },
    );
  });
}
```

**Key Patterns:**
- `pumpWidget()` to render widget tree
- `pump()` and `pumpAndSettle()` to advance animation frames
- `find.byKey()` to locate specific widgets (requires `Key` in source)
- `tester.widget<T>()` to access widget properties for assertions
- `MaterialApp` wrapper for widgets requiring Material context

## Mocking

**Framework:** No mocking library detected

**Patterns:**
- **No mocking** used in existing tests
- Tests use real model instances created via factory helpers
- Services tested via exposed static methods (`computeStatsForTest`, `statusTextColorForTest`)
- Widget tests use real `StreamController` (not mocked)

**What is NOT Mocked:**
- Model classes (use real instances with test data)
- Services (tested via public/test-exposed APIs)
- DateTime (use real `DateTime(2024, 3, 4)` instances)
- Colors, TimeOfDay, other Flutter primitives

**Future Mocking (Not Currently Used):**
- For Supabase calls: Consider `mockito` or `mocktail` package
- For NFC hardware: Consider injectable service with test double

## Test Data

**Fixtures:**
- No separate fixture files — data created inline via helper functions
- Factory pattern preferred:
```dart
DailySummary _makeSummary({
  required String dateLabel,
  required DailySummaryStatus status,
  DateTime? firstMasuk,
  DateTime? lastPulang,
  Duration? workDuration,
  String? employeeId,
  String? employeeName,
  int scanCount = 1,
}) {
  final employee = employeeId != null
      ? Employee(
          id: employeeId,
          name: employeeName ?? 'Emp $employeeId',
          isActive: true,
          createdAt: '',
          updatedAt: '',
        )
      : null;

  return DailySummary(
    dateLabel: dateLabel,
    employee: employee,
    outlet: null,
    firstMasuk: firstMasuk,
    lastPulang: lastPulang,
    workDuration: workDuration,
    totalBreak: Duration.zero,
    scanCount: scanCount,
    status: status,
  );
}
```

**Location:**
- Test data defined at top of test file (private helper functions)
- No shared fixtures directory

## Test Types

**Unit Tests:**
- Scope: Pure logic, model serialization, business rules
- Examples:
  - `test/models/shift_schedule_test.dart` — Tests `ShiftSlot` factories, serialization, date normalization
  - `test/services/pdf_service_color_test.dart` — Tests color mapping logic for PDF generation
  - `test/services/pdf_report_service_test.dart` — Tests statistics computation

**Widget Tests:**
- Scope: Widget rendering, user interaction, state updates
- Examples:
  - `test/widgets/overlay_pill_widget_test.dart` — Tests overlay pill UI rendering based on stream payloads

**Integration Tests:**
- Not detected in codebase

**E2E Tests:**
- Not used

## Coverage

**Requirements:** No coverage target enforced

**View Coverage:**
```bash
flutter test --coverage
# Generates coverage/lcov.info (standard Flutter location)
```

**Current State:**
- No `.coverage/` or `coverage/` directory in codebase
- No coverage threshold in CI configuration
- Tests exist for core models and services but coverage is sparse

## Common Patterns

**Model Serialization Tests:**
```dart
test('toJson → fromJson round-trips correctly', () {
  final original = ShiftSlot.pagi();
  final json = original.toJson();
  final restored = ShiftSlot.fromJson(json);

  expect(restored.name, original.name);
  expect(restored.startTime, original.startTime);
  expect(restored.endTime, original.endTime);
});
```

**Enum Extension Tests:**
```dart
test('label returns correct Indonesian labels', () {
  expect(ScheduleStatus.normal.label, 'Masuk');
  expect(ScheduleStatus.sakit.label, 'Sakit');
  expect(ScheduleStatus.izin.label, 'Izin');
  expect(ScheduleStatus.libur.label, 'Libur');
  expect(ScheduleStatus.cuti.label, 'Cuti');
});
```

**Factory Method Tests:**
```dart
test('sakit entry has correct status and display name', () {
  final emp = _makeEmployee('emp-1', 'Alice');
  final entry = ScheduleEntry.sakit(
    id: 'entry-2',
    date: DateTime(2024, 3, 5),
    employee: emp,
    shift: ShiftSlot.pagi(),
    notes: 'Demam',
  );

  expect(entry.status, ScheduleStatus.sakit);
  expect(entry.displayName, 'Alice (SAKIT)');
  expect(entry.isDayOff, true);
  expect(entry.notes, 'Demam');
});
```

**Date Normalization Tests:**
```dart
// Validates the date normalization pattern used in SQLite service
test('toIso8601String().split(T)[0] produces yyyy-MM-dd', () {
  final date = DateTime(2024, 3, 4, 15, 30, 45);
  final normalized = date.toIso8601String().split('T')[0];
  expect(normalized, '2024-03-04');
});

test('round-trip: DateTime → split(T)[0] → parse matches original date', () {
  final original = DateTime(2024, 12, 31, 23, 59, 59);
  final normalized = original.toIso8601String().split('T')[0];
  final parsed = DateTime.parse(normalized);

  expect(parsed.year, original.year);
  expect(parsed.month, original.month);
  expect(parsed.day, original.day);
});
```

**Color/Constant Mapping Tests:**
```dart
test('Sakit maps to red (#DC2626)', () {
  final color = PdfService.statusTextColorForTest('Sakit');
  expect(color, PdfColor.fromHex('DC2626'));
});

test('unknown status falls through to green (default)', () {
  final color = PdfService.statusTextColorForTest('UnknownStatus');
  expect(color, PdfColor.fromHex('16A34A'));
});
```

**Statistics/Aggregation Tests:**
```dart
test('2 employees x 2 days all normal hadir → totalHadir=4, rate=100%', () {
  final summaries = [
    _makeSummary(
      dateLabel: '2024-01-01',
      status: DailySummaryStatus.normal,
      firstMasuk: DateTime(2024, 1, 1, 8, 0),
      lastPulang: DateTime(2024, 1, 1, 17, 0),
      workDuration: const Duration(hours: 8),
      employeeId: 'emp1',
      scanCount: 2,
    ),
    // ... more summaries
  ];
  
  final stats = PdfReportService.computeStatsForTest(summaries);
  
  expect(stats.totalHadir, 4);
  expect(stats.attendanceRate, 100.0);
});
```

**Widget Stream Tests:**
```dart
testWidgets('stream update triggers widget rebuild', (tester) async {
  await pumpOverlay(tester);
  
  stream.add(_payload(mode: 'idle', outlet: 'Outlet A'));
  await tester.pump();
  
  final text = tester.widget<Text>(find.byKey(const Key('overlay-pill-outlet')));
  expect(text.data, 'Outlet A');
  
  stream.add(_payload(mode: 'idle', outlet: 'Outlet B'));
  await tester.pump();
  
  final updated = tester.widget<Text>(find.byKey(const Key('overlay-pill-outlet')));
  expect(updated.data, 'Outlet B');
});
```

## Test Documentation

**Doc Comments in Tests:**
```dart
/// Phase 8 — Schedule System Validation Tests
/// Tests model serialization, date handling, and entry logic
/// that underpin the Supabase-first load / SQLite cache architecture.

/// Phase 8.1 — PDF Export Validation Tests
/// Tests status/type color mapping and label correctness
/// that ensure PDF output matches UI badge colors.
```

**Pattern:**
- Tests include phase/feature context
- Explain **why** the test matters (not just what it tests)
- Reference architecture decisions ("Supabase-first load / SQLite cache")

## Async Testing

**Pattern:**
```dart
testWidgets('async widget updates', (tester) async {
  await pumpOverlay(tester);
  
  stream.add(payload);
  await tester.pump();           // Advance one frame
  await tester.pumpAndSettle();  // Wait for all animations
  
  // Assertions after async updates complete
  expect(find.text('Expected'), findsOneWidget);
});
```

**Key Points:**
- All widget tests use `async` callback: `(tester) async`
- `await pumpWidget()` to render initial tree
- `await pump()` to advance single frame after state change
- `await pumpAndSettle()` to wait for animations to complete

## Error Case Testing

**Pattern:**
```dart
test('fromJson with null status defaults to normal', () {
  final json = {
    'id': 'entry-x',
    'date': '2024-03-04T00:00:00.000',
    'employee_id': 'emp-1',
    'status': null,  // Null/missing field
  };
  final entry = ScheduleEntry.fromJson(json);
  expect(entry.status, ScheduleStatus.normal);  // Default fallback
});

test('empty string falls through to green (default)', () {
  final color = PdfService.statusTextColorForTest('');
  expect(color, PdfColor.fromHex('16A34A'));
});
```

## What's Tested

**Covered:**
- ✅ Model serialization (`fromJson`, `toJson`)
- ✅ Factory methods (e.g., `ShiftSlot.pagi()`, `ScheduleEntry.sakit()`)
- ✅ Enum extensions (`.label`, `.color`, `.fromString()`)
- ✅ Business logic (stats computation, date normalization)
- ✅ Color/constant mappings for PDF generation
- ✅ Widget rendering from stream data
- ✅ Getter properties (`isDraft`, `isWeekly`, `initial`)

**Not Covered:**
- ❌ Supabase queries (no integration tests)
- ❌ NFC scanning (hardware-dependent)
- ❌ SQLite operations (no database tests)
- ❌ Network connectivity checks
- ❌ Background services (foreground service, overlay)
- ❌ Navigation flows (GoRouter redirects)
- ❌ User interactions (button taps, form submissions)
- ❌ Screen-level state management (most screens untested)

## Test Gaps

**Missing Critical Tests:**
- **SyncService**: No tests for offline queue sync logic
- **NfcService**: No tests for UID extraction (hardware mock needed)
- **SqliteService**: No tests for database operations
- **AppProvider/AppNotifier**: No tests for state management
- **Admin screens**: No widget tests for dashboard, employees, reports
- **Kiosk screens**: Scan flow untested

**Priority Test Additions:**
1. `SyncService.syncPendingLogs()` — offline queue is critical path
2. `AppNotifier` state transitions — drives routing logic
3. `SqliteService` CRUD operations — offline data integrity
4. Kiosk scan screen flow — core user journey

---

*Testing analysis: 2024-12-20*

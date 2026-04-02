import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/employee.dart';
import 'package:absensi_enakko_flutter/models/employee_contract.dart';
import 'package:absensi_enakko_flutter/models/kiosk_scan_context.dart';
import 'package:absensi_enakko_flutter/models/pending_log.dart';
import 'package:absensi_enakko_flutter/models/shift_band.dart';
import 'package:absensi_enakko_flutter/providers/app_provider.dart';
import 'package:absensi_enakko_flutter/screens/kiosk/kiosk_idle_screen.dart';
import 'package:absensi_enakko_flutter/screens/kiosk/kiosk_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const employee = Employee(
    id: 'emp-1',
    name: 'Ayu',
    position: 'Barista',
    isActive: true,
    createdAt: '2026-03-01T00:00:00.000Z',
    updatedAt: '2026-03-01T00:00:00.000Z',
  );

  KioskScanContext buildContext({
    AttendanceType? lastType,
    bool breakFirstEligible = false,
  }) {
    return KioskScanContext(
      serverNowUtc: DateTime.utc(2026, 3, 27, 0, 2),
      serverNowWitaLabel: '08:02 WITA',
      logicalDate: DateTime(2026, 3, 27),
      lastAuthoritativeType: lastType,
      shiftBand: ShiftBand.pagi,
      employmentContract: EmployeeContract.fulltime,
      lateCutoffLocal: '08:00',
      breakFirstDeadlineLocal: '09:00',
      breakFirstEligible: breakFirstEligible,
    );
  }

  PendingLog buildPendingLog({
    required AttendanceType type,
    InitialScanIntent initialIntent = InitialScanIntent.none,
  }) {
    return PendingLog(
      localId: 'local-1',
      employeeId: employee.id,
      scanOutletId: 'outlet-1',
      type: type,
      deviceId: 'device-1',
      scannedAt: '2026-03-27T00:02:00.000Z',
      deviceCapturedAt: DateTime.utc(2026, 3, 27, 0, 2),
      captureMode: AttendanceCaptureMode.queued,
      queueOrder: 1,
      initialScanIntent: initialIntent,
      syncStatus: SyncStatus.pending,
      retryCount: 0,
      createdAt: '2026-03-27T00:02:00.000Z',
    );
  }

  Future<void> pumpScanScreen(
    WidgetTester tester, {
    KioskScanActionDebugState? actionState,
    KioskScanSuccessDebugState? successState,
    KioskScanSubmitDebugHandler? submitHandler,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appProvider.notifier).setDetectedEmployee(employee);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: KioskScanScreen.testable(
            debugActionState: actionState,
            debugSuccessState: successState,
            debugSubmitHandler: submitHandler,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows ISTIRAHAT DULU when first scan is eligible',
      (tester) async {
    await pumpScanScreen(
      tester,
      actionState: KioskScanActionDebugState(
        context: buildContext(breakFirstEligible: true),
      ),
    );

    expect(find.text('MASUK'), findsOneWidget);
    expect(find.text('ISTIRAHAT DULU'), findsOneWidget);
  });

  testWidgets('hides ISTIRAHAT DULU when first scan is not eligible', (
    tester,
  ) async {
    await pumpScanScreen(
      tester,
      actionState: KioskScanActionDebugState(
        context: buildContext(breakFirstEligible: false),
      ),
    );

    expect(find.text('ISTIRAHAT DULU'), findsNothing);
  });

  testWidgets('queued break-first pending log changes next action to selesai', (
    tester,
  ) async {
    await pumpScanScreen(
      tester,
      actionState: KioskScanActionDebugState(
        context: buildContext(),
        pendingLogs: [
          buildPendingLog(
            type: AttendanceType.breakTime,
            initialIntent: InitialScanIntent.breakFirst,
          ),
        ],
      ),
    );

    expect(find.text('SELESAI ISTIRAHAT'), findsOneWidget);
    expect(find.text('ISTIRAHAT DULU'), findsNothing);
  });

  testWidgets('break-first dialog shows locked copy and confirms submit', (
    tester,
  ) async {
    var submitted = false;

    await pumpScanScreen(
      tester,
      actionState: KioskScanActionDebugState(
        context: buildContext(breakFirstEligible: true),
      ),
      submitHandler: (_, initialIntent) {
        submitted = initialIntent == InitialScanIntent.breakFirst;
      },
    );

    await tester.tap(find.text('ISTIRAHAT DULU'));
    await tester.pumpAndSettle();

    expect(find.text('Mulai dengan istirahat?'), findsOneWidget);
    expect(
      find.text(
        'Scan ini akan dicatat sebagai istirahat lebih dulu. Setelah selesai, tap Selesai Istirahat.',
      ),
      findsOneWidget,
    );
    expect(find.text('Simpan Istirahat Dulu'), findsOneWidget);
    expect(find.text('Kembali ke Pilihan Scan'), findsOneWidget);

    await tester.tap(find.text('Simpan Istirahat Dulu'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
  });

  testWidgets('live success shows WITA time and break-first helper', (
    tester,
  ) async {
    await pumpScanScreen(
      tester,
      successState: const KioskScanSuccessDebugState(
        submittedType: AttendanceType.breakTime,
        authorityState: KioskScanAuthorityState.liveConfirmed,
        scannedAtWitaLabel: '07:02 WITA',
        initialScanIntent: InitialScanIntent.breakFirst,
      ),
    );

    expect(find.text('Berhasil!'), findsOneWidget);
    expect(find.text('Waktu WITA tercatat'), findsOneWidget);
    expect(find.text('07:02 WITA'), findsOneWidget);
    expect(find.text('Berikutnya tap Selesai Istirahat.'), findsOneWidget);
  });

  testWidgets('queued success shows pending copy without WITA claim', (
    tester,
  ) async {
    await pumpScanScreen(
      tester,
      successState: const KioskScanSuccessDebugState(
        submittedType: AttendanceType.masuk,
        authorityState: KioskScanAuthorityState.queuedPending,
      ),
    );

    expect(find.text('Tersimpan Sementara'), findsOneWidget);
    expect(
      find.text(
        'Scan disimpan di perangkat dan akan dikirim otomatis saat koneksi kembali.',
      ),
      findsOneWidget,
    );
    expect(find.text('Lihat tanda pending di layar utama.'), findsOneWidget);
    expect(find.text('Waktu WITA tercatat'), findsNothing);
  });

  testWidgets('idle screen exposes offline uncached copy', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: KioskIdleScreen.testable(
            debugOfflineUnavailable: true,
            debugNfcAvailable: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Belum Bisa Diproses Offline'), findsOneWidget);
    expect(
      find.text(
        'Karyawan ini belum tersimpan di perangkat. Sambungkan internet lalu coba lagi.',
      ),
      findsOneWidget,
    );
  });
}

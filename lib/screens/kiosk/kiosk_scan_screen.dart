import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/kiosk_scan_context.dart';
import '../../models/overlay_pill_state.dart';
import '../../models/shift_band.dart';
import '../../models/pending_log.dart';
import '../../providers/app_provider.dart';
import '../../services/badge_service.dart';
import '../../services/employee_cache_service.dart';
import '../../services/kiosk_background_service.dart';
import '../../services/kiosk_scan_authority_service.dart';
import '../../services/location_service.dart';
import '../../services/pattern_detection_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/streak_badge_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/badge_avatar.dart';

enum _ScanStep { selectAction, submitting, success, error }

@visibleForTesting
class KioskScanActionDebugState {
  final KioskScanContext context;
  final List<PendingLog> pendingLogs;

  const KioskScanActionDebugState({
    required this.context,
    this.pendingLogs = const [],
  });
}

typedef KioskScanSubmitDebugHandler = FutureOr<void> Function(
  AttendanceType type,
  InitialScanIntent initialScanIntent,
);

@visibleForTesting
class KioskScanSuccessDebugState {
  final AttendanceType submittedType;
  final KioskScanAuthorityState authorityState;
  final String scannedAtWitaLabel;
  final InitialScanIntent initialScanIntent;
  final int currentStreak;
  final int? milestoneCelebration;

  const KioskScanSuccessDebugState({
    required this.submittedType,
    this.authorityState = KioskScanAuthorityState.liveConfirmed,
    this.scannedAtWitaLabel = '07:00 WITA',
    this.initialScanIntent = InitialScanIntent.none,
    this.currentStreak = 0,
    this.milestoneCelebration,
  });
}

class KioskScanScreen extends ConsumerStatefulWidget {
  final KioskScanActionDebugState? debugActionState;
  final KioskScanSuccessDebugState? debugSuccessState;
  final KioskScanSubmitDebugHandler? debugSubmitHandler;

  const KioskScanScreen({super.key})
      : debugActionState = null,
        debugSuccessState = null,
        debugSubmitHandler = null;

  @visibleForTesting
  const KioskScanScreen.testable({
    super.key,
    this.debugActionState,
    this.debugSuccessState,
    this.debugSubmitHandler,
  });

  @override
  ConsumerState<KioskScanScreen> createState() => _KioskScanScreenState();
}

class _KioskScanScreenState extends ConsumerState<KioskScanScreen>
    with TickerProviderStateMixin {
  _ScanStep _step = _ScanStep.selectAction;
  String? _errorTitle;
  String? _errorBody;
  Timer? _resetTimer;

  KioskScanContext? _authorityContext;
  List<PendingLog> _pendingLogs = [];
  bool _loadingActionState = true;

  AttendanceType? _submittedType;
  KioskScanAuthorityState _successAuthorityState =
      KioskScanAuthorityState.liveConfirmed;
  String _successScannedAtWitaLabel = '';
  InitialScanIntent _submittedInitialIntent = InitialScanIntent.none;

  int _currentStreak = 0;
  int? _milestoneCelebration;

  final KioskScanAuthorityService _authorityService =
      KioskScanAuthorityService();

  late final ConfettiController _confettiCtrl;
  late final AnimationController _successScaleCtrl;
  late final Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();

    _confettiCtrl = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );
    _successScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successScaleCtrl,
      curve: Curves.elasticOut,
    );

    final debugSuccessState = widget.debugSuccessState;
    if (debugSuccessState != null) {
      _step = _ScanStep.success;
      _submittedType = debugSuccessState.submittedType;
      _successAuthorityState = debugSuccessState.authorityState;
      _successScannedAtWitaLabel = debugSuccessState.scannedAtWitaLabel;
      _submittedInitialIntent = debugSuccessState.initialScanIntent;
      _currentStreak = debugSuccessState.currentStreak;
      _milestoneCelebration = debugSuccessState.milestoneCelebration;
      _loadingActionState = false;
      _successScaleCtrl.value = 1;
      return;
    }

    final debugActionState = widget.debugActionState;
    if (debugActionState != null) {
      _authorityContext = debugActionState.context;
      _pendingLogs = List<PendingLog>.from(debugActionState.pendingLogs)
        ..sort((a, b) => a.queueOrder.compareTo(b.queueOrder));
      _loadingActionState = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BadgeService.instance.fetchAll();
      final appState = ref.read(appProvider);
      final employee = appState.detectedEmployee;
      final session = appState.kioskSession;
      if (employee != null && session != null) {
        _loadActionState(
          employee: employee,
          outletId: session.outletId,
          deviceId: session.deviceId,
        );
      } else {
        setState(() => _loadingActionState = false);
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _confettiCtrl.dispose();
    _successScaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActionState({
    required Employee employee,
    required String outletId,
    required String deviceId,
  }) async {
    KioskScanContext? resolvedContext;
    try {
      resolvedContext = await _authorityService.fetchContext(
        employeeId: employee.id,
        outletId: outletId,
        deviceId: deviceId,
      );
      await EmployeeCacheService.instance.putScanContext(
        employee.id,
        resolvedContext,
      );
    } catch (error) {
      debugPrint('[KioskScan] fetchContext failed: $error');
      resolvedContext = await EmployeeCacheService.instance.getScanContext(
        employee.id,
      );
    }

    List<PendingLog> pendingLogs = const [];
    try {
      pendingLogs = (await SqliteService.getPendingLogs())
          .where(
            (log) =>
                log.employeeId == employee.id &&
                log.scanOutletId == outletId &&
                log.deviceId == deviceId,
          )
          .toList()
        ..sort((a, b) => a.queueOrder.compareTo(b.queueOrder));
    } catch (error) {
      debugPrint('[KioskScan] load pending logs failed: $error');
    }

    if (!mounted) return;

    if (resolvedContext == null) {
      _showErrorState(
        title: 'Belum Bisa Diproses Offline',
        body:
            'Karyawan ini belum tersimpan di perangkat. Sambungkan internet lalu coba lagi.',
      );
      _scheduleReset(
        const Duration(milliseconds: AppConstants.errorResetDurationMs),
      );
      return;
    }

    setState(() {
      _authorityContext = resolvedContext;
      _pendingLogs = pendingLogs;
      _loadingActionState = false;
    });

    // Overnight debug logging
    if (resolvedContext != null) {
      final serverLocal = resolvedContext.serverNowUtc.toLocal();
      if (serverLocal.hour >= 17 || serverLocal.hour < 6) {
        debugPrint('[KioskScan] Overnight window: ${serverLocal.hour}h, band=${resolvedContext.shiftBand}, last=${resolvedContext.lastAuthoritativeType}');
      }
    }
  }

  AttendanceType? _resolveLastType() {
    if (_pendingLogs.isNotEmpty) {
      return _pendingLogs.last.type;
    }
    return _authorityContext?.lastAuthoritativeType;
  }

  Future<bool> _showLiburWarningDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.event_busy_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Text(
              'Hari Libur',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Jadwal hari ini adalah libur. Apakah kamu tetap ingin mencatat kehadiran?',
          style: TextStyle(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Lanjutkan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleMasukWithLiburCheck() async {
    final isLibur = _authorityContext?.shiftBand == ShiftBand.libur;
    if (isLibur) {
      final confirmed = await _showLiburWarningDialog();
      if (!confirmed) return;
    }
    await _submitAttendance(AttendanceType.masuk);
  }

  Future<void> _refreshPendingCount() async {
    final count = await SqliteService.countPendingLogs();
    ref.read(appProvider.notifier).setPendingCount(count);
  }

  Future<void> _syncPendingBestEffort() async {
    try {
      await SyncService.syncPendingLogs();
    } catch (error) {
      debugPrint('[KioskScan] background sync failed: $error');
    }
    await _refreshPendingCount();
  }

  Future<void> _submitAttendance(
    AttendanceType type, {
    InitialScanIntent initialScanIntent = InitialScanIntent.none,
  }) async {
    if (_step != _ScanStep.selectAction) return;

    final debugSubmitHandler = widget.debugSubmitHandler;
    if (debugSubmitHandler != null) {
      await debugSubmitHandler(type, initialScanIntent);
      return;
    }

    final session = ref.read(appProvider).kioskSession;
    final employee = ref.read(appProvider).detectedEmployee;
    final isBackup = ref.read(appProvider).isBackupMode;
    final backupNotes = ref.read(appProvider).backupNotes;
    if (session == null || employee == null) return;

    setState(() {
      _step = _ScanStep.submitting;
      _submittedType = type;
      _submittedInitialIntent = initialScanIntent;
    });

    LatLng? position;
    try {
      position = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 1), onTimeout: () => null);
    } catch (_) {}

    final deviceCapturedAt = DateTime.now();

    try {
      final liveResult = await _authorityService.recordScan(
        KioskScanRecordRequest(
          employeeId: employee.id,
          outletId: session.outletId,
          deviceId: session.deviceId,
          type: type,
          captureMode: AttendanceCaptureMode.live,
          deviceCapturedAt: deviceCapturedAt,
          initialScanIntent: initialScanIntent,
          isBackup: isBackup,
          notes: backupNotes,
          lat: position?.lat,
          lng: position?.lng,
        ),
      );

      final witaLabel = liveResult.scannedAtWitaLabel.isNotEmpty
          ? liveResult.scannedAtWitaLabel
          : _formatWitaLabel(liveResult.scannedAtUtc ?? deviceCapturedAt);

      await _pushAttendanceOverlayEvent(
        type: liveResult.recordedType,
        outletName: session.outletName,
      );

      if (!mounted) return;

      setState(() {
        _step = _ScanStep.success;
        _submittedType = liveResult.recordedType;
        _successAuthorityState = KioskScanAuthorityState.liveConfirmed;
        _successScannedAtWitaLabel = witaLabel;
        _submittedInitialIntent = liveResult.initialScanIntent;
      });
      _confettiCtrl.play();
      _successScaleCtrl.forward(from: 0);

      if (liveResult.recordedType == AttendanceType.masuk &&
          liveResult.scannedAtUtc != null) {
        final authoritativeWita = _projectUtcToWita(liveResult.scannedAtUtc!);
        unawaited(
          PatternDetectionService.instance
              .checkAndNotifyIfLate(
            employeeId: employee.id,
            outletId: session.outletId,
            scanTime: authoritativeWita,
          )
              .catchError((Object error) {
            debugPrint('[KioskScan] pattern check error: $error');
          }),
        );
        unawaited(_updateStreakAfterMasuk(employee.id));
      }

      _scheduleReset(
        const Duration(milliseconds: AppConstants.successScreenDurationMs),
      );
    } catch (error) {
      debugPrint('[KioskScan] live submit failed: $error');

      final cachedContext = _authorityContext ??
          await EmployeeCacheService.instance.getScanContext(employee.id);
      if (cachedContext == null) {
        if (!mounted) return;
        _showErrorState(
          title: 'Belum Bisa Diproses Offline',
          body:
              'Karyawan ini belum tersimpan di perangkat. Sambungkan internet lalu coba lagi.',
        );
        _scheduleReset(
          const Duration(milliseconds: AppConstants.errorResetDurationMs),
        );
        return;
      }

      try {
        await SqliteService.insertPendingLog(
          employeeId: employee.id,
          scanOutletId: session.outletId,
          type: type,
          lat: position?.lat,
          lng: position?.lng,
          deviceId: session.deviceId,
          scannedAt: deviceCapturedAt.toUtc().toIso8601String(),
          deviceCapturedAt: deviceCapturedAt,
          captureMode: AttendanceCaptureMode.queued,
          initialScanIntent: initialScanIntent,
          isBackup: isBackup,
          notes: backupNotes,
        );

        await _refreshPendingCount();
        await _syncPendingBestEffort();
        await _pushAttendanceOverlayEvent(
          type: type,
          outletName: session.outletName,
        );

        if (!mounted) return;

        setState(() {
          _step = _ScanStep.success;
          _successAuthorityState = KioskScanAuthorityState.queuedPending;
          _successScannedAtWitaLabel = '';
        });
        _successScaleCtrl.forward(from: 0);
        _scheduleReset(
          const Duration(milliseconds: AppConstants.successScreenDurationMs),
        );
      } catch (queueError) {
        debugPrint('[KioskScan] queued fallback failed: $queueError');
        if (!mounted) return;
        _showErrorState(title: 'Gagal menyimpan absensi');
        _scheduleReset(
          const Duration(milliseconds: AppConstants.errorResetDurationMs),
        );
      }
    }
  }

  Future<void> _pushAttendanceOverlayEvent({
    required AttendanceType type,
    required String outletName,
  }) async {
    try {
      final employee = ref.read(appProvider).detectedEmployee;
      final badge =
          BadgeService.instance.getBadgeByIdSync(employee?.activeBadgeId);
      final badgeEmoji = badge?.emoji ?? '';
      final now = DateTime.now();
      final state = OverlayPillState(
        mode: OverlayPillMode.event,
        outlet: outletName.trim().isEmpty
            ? OverlayPillState.defaultOutlet
            : outletName.trim(),
        time: _formatLocalTime(now),
        attendanceType: type.value,
        accentHex: _colorToHex(type.color),
        eventUntilEpochMs:
            now.add(const Duration(seconds: 8)).millisecondsSinceEpoch,
        expanded: true,
        badgeEmoji: badgeEmoji,
      );
      await KioskBackgroundService.updateOverlayState(state);
      KioskBackgroundService.markEventActive(state.eventUntilEpochMs);
    } catch (error) {
      debugPrint('[KioskScan] push overlay event error: $error');
    }
  }

  String _formatLocalTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatWitaLabel(DateTime value) {
    final projected = _projectUtcToWita(value);
    final h = projected.hour.toString().padLeft(2, '0');
    final m = projected.minute.toString().padLeft(2, '0');
    return '$h:$m WITA';
  }

  DateTime _projectUtcToWita(DateTime value) {
    final projected =
        (value.isUtc ? value : value.toUtc()).add(const Duration(hours: 8));
    return DateTime(
      projected.year,
      projected.month,
      projected.day,
      projected.hour,
      projected.minute,
      projected.second,
      projected.millisecond,
      projected.microsecond,
    );
  }

  String _colorToHex(Color color) {
    final argb =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${argb.substring(2)}';
  }

  void _scheduleReset(Duration delay) {
    _resetTimer?.cancel();
    _resetTimer = Timer(delay, () {
      if (mounted) {
        ref.read(appProvider.notifier).resetScanFlow();
        context.go('/kiosk');
      }
    });
  }

  void _showErrorState({
    required String title,
    String? body,
  }) {
    setState(() {
      _step = _ScanStep.error;
      _errorTitle = title;
      _errorBody = body;
    });
  }

  Future<void> _updateStreakAfterMasuk(String employeeId) async {
    try {
      final result = await SupabaseClientFactory.admin.rpc(
        'update_employee_streak',
        params: {'p_employee_id': employeeId},
      );
      if (result != null && mounted) {
        final streak = (result['current_streak'] as num?)?.toInt() ?? 0;
        setState(() => _currentStreak = streak);
        final milestone =
            await StreakBadgeService.instance.checkAndAwardMilestone(
          employeeId: employeeId,
          currentStreak: streak,
        );
        if (milestone != null && mounted) {
          setState(() => _milestoneCelebration = milestone);
          _confettiCtrl.play();
        }
      }
    } catch (error) {
      debugPrint('[KioskScan] Streak update failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(appProvider).detectedEmployee;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: switch (_step) {
          _ScanStep.selectAction => _buildActionSelection(employee),
          _ScanStep.submitting => _buildSubmitting(),
          _ScanStep.success => _buildSuccess(employee),
          _ScanStep.error => _buildError(),
        },
      ),
    );
  }

  Widget _buildActionSelection(Employee? employee) {
    final name = employee?.name ?? '-';
    final badge =
        BadgeService.instance.getBadgeByIdSync(employee?.activeBadgeId);

    return Column(
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                BadgeAvatar(
                  photoUrl: employee?.photoUrl,
                  name: name,
                  size: 56,
                  badge: badge,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if ((employee?.position ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          employee!.position!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ref.watch(appProvider).isBackupMode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFF0891B2).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.support_agent_rounded,
                              size: 12,
                              color: Color(0xFF0891B2),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'BACKUP',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF0891B2),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Terverifikasi',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PILIH JENIS ABSENSI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _loadingActionState
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : _buildSmartButtons(),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            ref.read(appProvider.notifier).resetScanFlow();
            context.go('/kiosk');
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          label: const Text(
            'Kembali',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSmartButtons() {
    final lastType = _resolveLastType();
    final buttons = <Widget>[];

    void addButton(Widget button) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 8));
      buttons.add(button);
    }

    switch (lastType) {
      case null:
        addButton(_AttendanceButton(
          type: AttendanceType.masuk,
          onTap: () => _handleMasukWithLiburCheck(),
        ));
        break;
      case AttendanceType.masuk:
      case AttendanceType.kembali:
        addButton(_AttendanceButton(
          type: AttendanceType.breakTime,
          onTap: () => _submitAttendance(AttendanceType.breakTime),
        ));
        addButton(_AttendanceButton(
          type: AttendanceType.pulang,
          onTap: () => _submitAttendance(AttendanceType.pulang),
        ));
        break;
      case AttendanceType.breakTime:
        addButton(_AttendanceButton(
          type: AttendanceType.kembali,
          customLabel: 'SELESAI ISTIRAHAT',
          customIcon: Icons.play_circle_outline_rounded,
          onTap: () => _submitAttendance(AttendanceType.kembali),
        ));
        addButton(_AttendanceButton(
          type: AttendanceType.pulang,
          onTap: () => _submitAttendance(AttendanceType.pulang),
        ));
        break;
      case AttendanceType.pulang:
      case AttendanceType.sakit:
      case AttendanceType.izin:
        addButton(_AttendanceButton(
          type: AttendanceType.masuk,
          onTap: () => _handleMasukWithLiburCheck(),
        ));
        break;
    }

    return Column(children: buttons);
  }

  Widget _buildSubmitting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Menyimpan absensi...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(Employee? employee) {
    final isQueued =
        _successAuthorityState == KioskScanAuthorityState.queuedPending;
    final accentColor = isQueued
        ? const Color(0xFF92400E)
        : switch (_submittedType) {
            AttendanceType.masuk => AppColors.success,
            AttendanceType.kembali => const Color(0xFF0891B2),
            AttendanceType.breakTime => const Color(0xFFD97706),
            AttendanceType.pulang => const Color(0xFFB91C1C),
            AttendanceType.sakit => const Color(0xFFDC2626),
            AttendanceType.izin => const Color(0xFF2563EB),
            null => AppColors.success,
          };
    final medallionColor = isQueued ? const Color(0xFFD97706) : accentColor;
    final medallionIcon =
        isQueued ? Icons.schedule_rounded : Icons.check_rounded;
    final actionLabel = () {
      if (_submittedType == AttendanceType.kembali) {
        return 'SELESAI ISTIRAHAT';
      }
      return (_submittedType?.label ?? 'Absensi').toUpperCase();
    }();
    final statusLine = isQueued
        ? 'Scan disimpan di perangkat dan akan dikirim otomatis saat koneksi kembali.'
        : '${_submittedType?.label ?? 'Absensi'} tercatat';
    final witaLabel = _successScannedAtWitaLabel.isEmpty
        ? (_authorityContext?.serverNowWitaLabel ?? '--:-- WITA')
        : _successScannedAtWitaLabel;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (!isQueued)
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0,
              numberOfParticles: 30,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.2,
              colors: const [
                Color(0xFF22C55E),
                Color(0xFFF59E0B),
                Color(0xFFDC2626),
                Colors.white,
              ],
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _successScaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: medallionColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: medallionColor.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(medallionIcon, color: Colors.white, size: 56),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isQueued ? 'Tersimpan Sementara' : 'Berhasil!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusLine,
                  style: TextStyle(
                    fontSize: isQueued ? 14 : 18,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (employee != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Builder(
                    builder: (_) {
                      final badge = BadgeService.instance
                          .getBadgeByIdSync(employee.activeBadgeId);
                      if (badge == null || badge.name.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              badge.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              badge.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: badge.color1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
                if (!isQueued)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Waktu WITA tercatat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          witaLabel,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Lihat tanda pending di layar utama.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isQueued &&
                    _submittedType == AttendanceType.masuk &&
                    _currentStreak >= 2) ...[
                  const SizedBox(height: 16),
                  _buildStreakRow(),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Kembali ke layar utama...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakRow() {
    if (_milestoneCelebration != null) {
      final milestoneText = _milestoneCelebration == 90
          ? 'Streak 90 Hari! Luar Biasa!'
          : 'Streak $_milestoneCelebration Hari!';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 24,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Text(
            milestoneText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 24,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(width: 8),
        Text(
          '$_currentStreak hari berturut-turut!',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorTitle ?? 'Terjadi kesalahan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorBody != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorBody!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Kembali otomatis...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final AttendanceType type;
  final VoidCallback onTap;
  final String? customLabel;
  final IconData? customIcon;

  const _AttendanceButton({
    required this.type,
    required this.onTap,
    this.customLabel,
    this.customIcon,
  });

  Color get _color {
    switch (type) {
      case AttendanceType.masuk:
        return AppColors.success;
      case AttendanceType.kembali:
        return const Color(0xFF0891B2);
      case AttendanceType.breakTime:
        return const Color(0xFFF59E0B);
      case AttendanceType.pulang:
        return AppColors.danger;
      case AttendanceType.sakit:
        return const Color(0xFFDC2626);
      case AttendanceType.izin:
        return const Color(0xFF2563EB);
    }
  }

  Color get _bgColor {
    switch (type) {
      case AttendanceType.masuk:
        return AppColors.successLight;
      case AttendanceType.kembali:
        return const Color(0xFFE0F2FE);
      case AttendanceType.breakTime:
        return const Color(0xFFFEF3C7);
      case AttendanceType.pulang:
        return AppColors.dangerLight;
      case AttendanceType.sakit:
        return const Color(0xFFFEE2E2);
      case AttendanceType.izin:
        return const Color(0xFFDBEAFE);
    }
  }

  IconData get _icon {
    if (customIcon != null) return customIcon!;
    switch (type) {
      case AttendanceType.masuk:
        return Icons.login_rounded;
      case AttendanceType.kembali:
        return Icons.play_circle_outline_rounded;
      case AttendanceType.breakTime:
        return Icons.pause_circle_outline_rounded;
      case AttendanceType.pulang:
        return Icons.logout_rounded;
      case AttendanceType.sakit:
        return Icons.sick_outlined;
      case AttendanceType.izin:
        return Icons.event_note_outlined;
    }
  }

  String get _label {
    if (customLabel != null) return customLabel!;
    switch (type) {
      case AttendanceType.masuk:
        return 'MASUK';
      case AttendanceType.kembali:
        return 'KEMBALI';
      case AttendanceType.breakTime:
        return 'ISTIRAHAT';
      case AttendanceType.pulang:
        return 'PULANG';
      case AttendanceType.sakit:
        return 'SAKIT';
      case AttendanceType.izin:
        return 'IZIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _color.withValues(alpha: 0.35), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _color,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _color.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/attendance_log.dart';
import '../../models/employee.dart';
import '../../models/overlay_pill_state.dart';
import '../../providers/app_provider.dart';
import '../../services/kiosk_background_service.dart';
import '../../services/location_service.dart';
import '../../services/sqlite_service.dart';
import '../../services/sync_service.dart';

enum _ScanStep { selectAction, submitting, success, error }

class KioskScanScreen extends ConsumerStatefulWidget {
  const KioskScanScreen({super.key});

  @override
  ConsumerState<KioskScanScreen> createState() => _KioskScanScreenState();
}

class _KioskScanScreenState extends ConsumerState<KioskScanScreen>
    with TickerProviderStateMixin {
  _ScanStep _step = _ScanStep.selectAction;
  String? _errorMessage;
  Timer? _resetTimer;

  // Smart break: last attendance type of this employee today
  AttendanceType? _lastType;
  bool _loadingLastType = true;

  // Submitted type — shown in success screen
  AttendanceType? _submittedType;

  // Confetti & success animation
  late final ConfettiController _confettiCtrl;
  late final AnimationController _successScaleCtrl;
  late final Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();

    // Confetti controller — single burst, auto-stop setelah 1.5s
    _confettiCtrl = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );

    // Scale animation for checkmark (ElasticOut bounce)
    _successScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successScaleCtrl,
      curve: Curves.elasticOut,
    );

    // Load smart break status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employee = ref.read(appProvider).detectedEmployee;
      if (employee != null) {
        _loadLastAttendance(employee.id);
      } else {
        setState(() => _loadingLastType = false);
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

  // ── Smart break: fetch last attendance ────────────────────────────────────

  Future<void> _loadLastAttendance(String employeeId) async {
    try {
      // 24h window: covers overnight shifts (e.g. 22:00 → 06:00 next day)
      // Safety net: no record in 24h → _lastType = null → Masuk shown (correct)
      final cutoff = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toUtc()
          .toIso8601String();

      final data = await SupabaseClientFactory.kiosk
          .from('attendance_logs')
          .select('type, scanned_at')
          .eq('employee_id', employeeId)
          .gte('scanned_at', cutoff)
          .order('scanned_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (data != null && mounted) {
        setState(() {
          _lastType = AttendanceTypeExt.fromString(data['type'] as String);
          // pulang → _lastType = pulang → _buildSmartButtons shows Masuk (new cycle) ✓
          // masuk/kembali/breakTime within 24h → correct next-step buttons shown ✓
        });
      }
      // null → no log in last 24h → _lastType stays null → Masuk shown ✓ (safety net)
    } catch (_) {
      // Network/timeout → _lastType stays null → show Masuk as safe fallback
    } finally {
      if (mounted) setState(() => _loadingLastType = false);
    }
  }

  // ── Submit attendance ─────────────────────────────────────────────────────

  Future<void> _submitAttendance(AttendanceType type) async {
    if (_step != _ScanStep.selectAction) return;

    final session = ref.read(appProvider).kioskSession;
    final employee = ref.read(appProvider).detectedEmployee;
    final isBackup = ref.read(appProvider).isBackupMode;
    final backupNotes = ref.read(appProvider).backupNotes;
    if (session == null || employee == null) return;

    setState(() {
      _step = _ScanStep.submitting;
      _submittedType = type;
    });

    try {
      // Best-effort GPS — max 1 second (faster than before)
      LatLng? position;
      try {
        position = await LocationService.getCurrentPosition()
            .timeout(const Duration(seconds: 1), onTimeout: () => null);
      } catch (_) {}

      final now = DateTime.now().toUtc().toIso8601String();

      await SqliteService.insertPendingLog(
        employeeId: employee.id,
        scanOutletId: session.outletId,
        type: type,
        lat: position?.lat,
        lng: position?.lng,
        deviceId: session.deviceId,
        scannedAt: now,
        isBackup: isBackup,
        notes: backupNotes,
      );

      // Auto-assign sudah ditangani di idle screen saat konfirmasi outlet
      // Hanya lakukan assign ulang jika bukan mode backup dan outlet berbeda
      if (!isBackup && employee.homeOutletId != session.outletId) {
        try {
          await SupabaseClientFactory.admin.from('employees').update({
            'home_outlet_id': session.outletId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', employee.id);
          debugPrint(
              '[AutoAssign] ${employee.name} moved to outlet ${session.outletId}');
        } catch (e) {
          debugPrint('[AutoAssign] Failed: $e');
          // Continue - absensi tetap tercatat meski auto-assign gagal
        }
      }

      // Update pending badge count
      final count = await SqliteService.countPendingLogs();
      ref.read(appProvider.notifier).setPendingCount(count);

      // Sync in background — best-effort
      try {
        await SyncService.syncPendingLogs();
        final newCount = await SqliteService.countPendingLogs();
        ref.read(appProvider.notifier).setPendingCount(newCount);
      } catch (_) {}

      await _pushAttendanceOverlayEvent(
        type: type,
        outletName: session.outletName,
      );

      if (mounted) {
        setState(() => _step = _ScanStep.success);
        // Start confetti + bounce animation
        _confettiCtrl.play();
        _successScaleCtrl.forward();
        // Auto-close after success
        _scheduleReset(
            const Duration(milliseconds: AppConstants.successScreenDurationMs));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _ScanStep.error;
          _errorMessage = 'Gagal menyimpan absensi';
        });
        _scheduleReset(
            const Duration(milliseconds: AppConstants.errorResetDurationMs));
      }
    }
  }

  Future<void> _pushAttendanceOverlayEvent({
    required AttendanceType type,
    required String outletName,
  }) async {
    try {
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
      );

      final keepOverlayInForeground =
          ref.read(appProvider).keepOverlayInForeground;
      if (keepOverlayInForeground) {
        final result = await KioskBackgroundService.ensureOverlayVisible(state);
        _showOverlayWarningToast(result);
      } else {
        await KioskBackgroundService.updateOverlayState(state);
      }
    } catch (e) {
      debugPrint('[KioskScan] push overlay event error: $e');
    }
  }

  void _showOverlayWarningToast(OverlayShowResult result) {
    if (!mounted) return;

    String? message;
    if (result == OverlayShowResult.permissionDenied) {
      message = 'Izin overlay belum aktif. Event absensi tidak ditampilkan.';
    } else if (result == OverlayShowResult.showFailed) {
      message = 'Overlay event gagal tampil. Coba lagi setelah beberapa detik.';
    }

    if (message == null) return;

    toastification.show(
      context: context,
      alignment: Alignment.topCenter,
      type: ToastificationType.warning,
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 3),
      title: const Text(
        'Peringatan Overlay',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      description: Text(message),
      showProgressBar: false,
    );
  }

  String _formatLocalTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(appProvider).detectedEmployee;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildBody(employee),
      ),
    );
  }

  Widget _buildBody(Employee? employee) {
    switch (_step) {
      case _ScanStep.selectAction:
        return _buildActionSelection(employee);
      case _ScanStep.submitting:
        return _buildSubmitting();
      case _ScanStep.success:
        return _buildSuccess(employee);
      case _ScanStep.error:
        return _buildError();
    }
  }

  // ── Action Selection ──────────────────────────────────────────────────────

  Widget _buildActionSelection(Employee? employee) {
    final name = employee?.name ?? '-';
    final position = employee?.position;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final photoUrl = employee?.photoUrl;

    return Column(
      children: [
        const SizedBox(height: 32),

        // ── EMPLOYEE CARD ─────────────────────────────────────────────
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                _buildAvatarCircle(photoUrl, initial, 56),
                const SizedBox(width: 16),

                // Name + position
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
                      if (position != null && position.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          position,
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

                // Verified badge + Backup badge
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Backup badge (hanya muncul saat mode backup)
                    if (ref.watch(appProvider).isBackupMode) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE), // Light cyan
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF0891B2).withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.support_agent_rounded,
                                size: 12, color: Color(0xFF0891B2)),
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
                    // Verified badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              size: 12, color: AppColors.success),
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

        // ── SECTION LABEL ─────────────────────────────────────────────
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

        // ── SMART BUTTONS ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _loadingLastType
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : _buildSmartButtons(),
        ),

        const Spacer(),

        // ── CANCEL ────────────────────────────────────────────────────
        TextButton.icon(
          onPressed: () {
            ref.read(appProvider.notifier).resetScanFlow();
            context.go('/kiosk');
          },
          icon: const Icon(Icons.arrow_back_rounded,
              size: 16, color: AppColors.textMuted),
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

  /// Smart button builder: shows relevant buttons based on last attendance type
  Widget _buildSmartButtons() {
    // Determine which buttons to show based on last scan today
    // null → belum ada scan hari ini → Masuk
    // masuk → Istirahat + Pulang
    // breakTime → Selesai Istirahat + Pulang
    // pulang → Masuk (lembur / hari baru edge case)

    final buttons = <Widget>[];

    switch (_lastType) {
      case null:
        // Belum scan hari ini → hanya Masuk
        buttons.add(_AttendanceButton(
          type: AttendanceType.masuk,
          onTap: () => _submitAttendance(AttendanceType.masuk),
        ));
        break;

      case AttendanceType.masuk:
        // Sudah masuk → Istirahat + Pulang
        buttons.add(_AttendanceButton(
          type: AttendanceType.breakTime,
          onTap: () => _submitAttendance(AttendanceType.breakTime),
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_AttendanceButton(
          type: AttendanceType.pulang,
          onTap: () => _submitAttendance(AttendanceType.pulang),
        ));
        break;

      case AttendanceType.kembali:
        // Seharusnya tidak terjadi (kembali → state sudah kembali bekerja)
        // Tampilkan pilihan sama seperti setelah masuk
        buttons.add(_AttendanceButton(
          type: AttendanceType.breakTime,
          onTap: () => _submitAttendance(AttendanceType.breakTime),
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_AttendanceButton(
          type: AttendanceType.pulang,
          onTap: () => _submitAttendance(AttendanceType.pulang),
        ));
        break;

      case AttendanceType.breakTime:
        // Sedang istirahat → Kembali Bekerja + Pulang
        buttons.add(_AttendanceButton(
          type: AttendanceType.kembali,
          customLabel: 'SELESAI ISTIRAHAT',
          customIcon: Icons.play_circle_outline_rounded,
          onTap: () => _submitAttendance(AttendanceType.kembali),
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_AttendanceButton(
          type: AttendanceType.pulang,
          onTap: () => _submitAttendance(AttendanceType.pulang),
        ));
        break;

      case AttendanceType.pulang:
        // Sudah pulang → hanya Masuk (lembur / hari baru)
        buttons.add(_AttendanceButton(
          type: AttendanceType.masuk,
          onTap: () => _submitAttendance(AttendanceType.masuk),
        ));
        break;

      case AttendanceType.sakit:
      case AttendanceType.izin:
        // Sakit/Izin input dari admin, treat seperti belum scan
        buttons.add(_AttendanceButton(
          type: AttendanceType.masuk,
          onTap: () => _submitAttendance(AttendanceType.masuk),
        ));
        break;
    }

    return Column(children: buttons);
  }

  // ── Avatar helper ─────────────────────────────────────────────────────────

  Widget _buildAvatarCircle(String? photoUrl, String initial, double size) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(width: size, height: size, color: Colors.grey.shade200),
          errorWidget: (context, url, error) => _initialCircle(initial, size),
        ),
      );
    }
    return _initialCircle(initial, size);
  }

  Widget _initialCircle(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.43,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Submitting ────────────────────────────────────────────────────────────

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

  // ── Success — animasi ceklis + confetti ───────────────────────────────────

  Widget _buildSuccess(Employee? employee) {
    final typeLabel = _submittedType?.label ?? 'Absensi';
    final typeColor = switch (_submittedType) {
      AttendanceType.masuk => AppColors.success,
      AttendanceType.kembali => const Color(0xFF0891B2),
      AttendanceType.breakTime => const Color(0xFFF59E0B),
      AttendanceType.pulang => AppColors.danger,
      AttendanceType.sakit => const Color(0xFFDC2626),
      AttendanceType.izin => const Color(0xFF2563EB),
      null => AppColors.success,
    };

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti burst from center-top
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0, // single burst, bukan continuous rain
            numberOfParticles: 30, // cukup padat tapi tidak lebay
            maxBlastForce: 25,
            minBlastForce: 10,
            gravity: 0.2, // jatuh pelan & natural
            colors: const [
              Color(0xFF22C55E), // hijau sukses
              Color(0xFFF59E0B), // kuning aksen
              Color(0xFFDC2626), // merah brand
              Colors.white,
            ],
          ),
        ),

        // Main success content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bouncing checkmark circle
                ScaleTransition(
                  scale: _successScaleAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Berhasil!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$typeLabel tercatat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
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
                ],

                const SizedBox(height: 32),

                // Subtle returning indicator
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
                    Text(
                      'Kembali ke layar utama...',
                      style: const TextStyle(
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

  // ── Error ─────────────────────────────────────────────────────────────────

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
              _errorMessage ?? 'Terjadi kesalahan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
              textAlign: TextAlign.center,
            ),
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

// ---------------------------------------------------------------------------
// Attendance action button — supports custom label + icon override
// ---------------------------------------------------------------------------

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
              border: Border.all(color: _color.withOpacity(0.35), width: 1.5),
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
                  color: _color.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, HapticFeedback, WriteBuffer;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/attendance_log.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import 'face_capture_state_machine.dart';

class CameraFacePreview extends StatefulWidget {
  final ValueChanged<Uint8List> onPhotoCaptured;
  final VoidCallback? onCancel;
  final AttendanceType pendingAction;

  const CameraFacePreview({
    super.key,
    required this.onPhotoCaptured,
    this.onCancel,
    this.pendingAction = AttendanceType.masuk,
  });

  @override
  State<CameraFacePreview> createState() => _CameraFacePreviewState();
}

class _CameraFacePreviewState extends State<CameraFacePreview>
    with TickerProviderStateMixin {
  final FaceCaptureStateMachine _fsm = FaceCaptureStateMachine();
  FaceDetectionResult _last = const FaceDetectionResult.empty();
  Uint8List? _capturedBytes;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initializing = true;
  bool _processingFrame = false;
  bool _capturing = false;
  String? _error;

  // ── Animation layer ──────────────────────────────────────────────
  // The painter is driven entirely by these controllers (NOT setState in the
  // frame callback), so live camera processing never forces an expensive
  // animated rebuild. setState in _processFrame only updates _last/_fsm; the
  // ring + ripple keep ticking independently.

  /// Continuous slow rotation for the idle/searching "scanning" sweep.
  late final AnimationController _sweep;

  /// Soft breathing pulse of the guide oval while we wait for a face.
  late final AnimationController _breathe;

  /// 0→1 fill of the progress ring. Animated toward a target that depends on
  /// the capture state so the ring smoothly grows/shrinks instead of jumping.
  late final AnimationController _progress;

  /// Spring-scale + fade-in for the success checkmark.
  late final AnimationController _success;

  /// One-shot expanding ripple emitted on a confirmed alignment lock.
  late final AnimationController _lock;

  /// Drives a short 0→1 glide used to lerp the ring color between states
  /// (grey → amber → green / red) so transitions slide rather than snap.
  late final AnimationController _colorGlide;
  Color _ringColorFrom = _kNeutral;
  Color _ringColorTo = _kNeutral;

  late Listenable _painterRepaint;

  CaptureState _renderedState = CaptureState.searching;

  static const Color _kNeutral = Color(0xFFE5E7EB); // soft white-grey guide

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _success = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _lock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _colorGlide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // Merge the controllers that actually move the painter. The face box is
    // repainted via the painter's own `faceBox` field on setState ticks; the
    // animations below repaint at 60fps without rebuilding the widget tree.
    _painterRepaint =
        Listenable.merge([_sweep, _breathe, _progress, _lock, _colorGlide]);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _sweep.dispose();
    _breathe.dispose();
    _progress.dispose();
    _success.dispose();
    _lock.dispose();
    _colorGlide.dispose();
    unawaited(CameraService.instance.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await CameraService.instance.initialize();
      final controller = CameraService.instance.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw StateError('Kamera belum siap');
      }
      if (!controller.supportsImageStreaming()) {
        throw StateError('Perangkat tidak mendukung face preview stream');
      }
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.startImageStream(_handleCameraImage);
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Kamera belum bisa digunakan';
      });
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (_processingFrame || _capturing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameProcessed).inMilliseconds <
        AppConstants.attendancePhotoFaceThrottleMs) {
      return;
    }
    _lastFrameProcessed = now;
    _processingFrame = true;
    unawaited(_processFrame(image, now));
  }

  Future<void> _processFrame(CameraImage image, DateTime now) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final result = await FaceDetectionService.instance.processImage(inputImage);
      if (!mounted || _capturing) return;
      final newState = _fsm.onDetection(result, now);
      setState(() => _last = result);
      _onStateChanged(newState);
      if (newState == CaptureState.capturing) {
        unawaited(_capture());
      }
    } catch (_) {
      // swallow; state machine will re-prompt if needed
    } finally {
      _processingFrame = false;
    }
  }

  /// Reacts to FSM transitions: retargets the progress ring, glides the ring
  /// color, fires ripples/haptics. Cheap — only runs on a real state change.
  void _onStateChanged(CaptureState state) {
    if (state == _renderedState) return;
    final previous = _renderedState;
    _renderedState = state;

    _animateRingColorTo(_targetRingColor(state));

    switch (state) {
      case CaptureState.searching:
      case CaptureState.retry:
        _progress.animateTo(0, curve: Curves.easeOut);
        break;
      case CaptureState.aligning:
        // Locked on — celebrate with a ripple + crisp haptic, then begin
        // filling the ring as the user holds steady.
        if (previous == CaptureState.searching) {
          _lock.forward(from: 0);
          HapticFeedback.selectionClick();
        }
        _progress.animateTo(0.55, curve: Curves.easeOutCubic);
        break;
      case CaptureState.promptBlink:
        _progress.animateTo(0.82, curve: Curves.easeOutCubic);
        break;
      case CaptureState.capturing:
      case CaptureState.done:
        // Complete the ring instantly on blink-success. The check pop +
        // haptic fire in _capture() when the frozen frame is shown, so they
        // land together with the shutter (not over the still-live preview).
        _progress.animateTo(1, curve: Curves.easeOutCubic);
        break;
      case CaptureState.exhausted:
        _progress.animateTo(1, curve: Curves.easeOut);
        HapticFeedback.heavyImpact();
        break;
    }
  }

  /// Retargets the ring color and restarts the short glide controller. The
  /// painter (which listens to `_colorGlide`) lerps `_ringColorFrom→_ringColorTo`
  /// over the glide, so no setState is needed here — the color slides smoothly.
  void _animateRingColorTo(Color target) {
    if (target == _ringColorTo) return;
    // Freeze the currently displayed color as the new origin so a mid-flight
    // transition keeps gliding instead of snapping back.
    _ringColorFrom = _currentRingColor();
    _ringColorTo = target;
    _colorGlide.forward(from: 0);
  }

  Color _currentRingColor() =>
      Color.lerp(_ringColorFrom, _ringColorTo, _colorGlide.value) ??
      _ringColorTo;

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final bytes = await CameraService.instance.capturePhoto();
      if (!mounted) return;
      setState(() => _capturedBytes = bytes);
      _success.forward(from: 0);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(
        const Duration(milliseconds: AppConstants.attendancePhotoPreviewMs),
      );
      _fsm.markDone();
      if (mounted) widget.onPhotoCaptured(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Foto gagal diambil';
      });
      _fsm.reset();
      unawaited(_initialize());
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = CameraService.instance.controller;
    final camera = CameraService.instance.cameraDescription;
    if (controller == null || camera == null) return null;
    final rotation = _inputImageRotation(camera, controller.value.deviceOrientation);
    if (rotation == null) return null;
    final format = _inputImageFormat(image.format);
    if (format == null) return null;
    final bytes = _cameraImageBytes(image);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    const orientations = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final rotationCompensation = orientations[orientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + rotationCompensation) % 360
        : (camera.sensorOrientation - rotationCompensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation);
  }

  InputImageFormat? _inputImageFormat(ImageFormat format) {
    final raw = format.raw;
    if (raw is int) {
      final parsed = InputImageFormatValue.fromRawValue(raw);
      if (parsed != null) return parsed;
    }
    switch (format.group) {
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv_420_888;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return null;
    }
  }

  Uint8List _cameraImageBytes(CameraImage image) {
    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  // ── Copy ─────────────────────────────────────────────────────────
  // Large friendly headline + quiet helper subtitle, per state, in Indonesian.

  String get _headline {
    if (_fsm.state == CaptureState.searching) {
      switch (_last.alignment) {
        case FaceAlignment.tooSmall:
          return 'Mendekat sedikit';
        case FaceAlignment.tooBig:
          return 'Mundur sedikit';
        case FaceAlignment.offCenter:
          return 'Geser ke tengah';
        case FaceAlignment.tilted:
          return 'Hadapkan wajah lurus';
        default:
          return 'Posisikan wajah di dalam lingkaran';
      }
    }
    switch (_fsm.state) {
      case CaptureState.aligning:
        return 'Tahan sebentar…';
      case CaptureState.promptBlink:
        return 'Kedipkan mata';
      case CaptureState.retry:
        return 'Coba kedipkan lagi';
      case CaptureState.exhausted:
        return 'Gagal mendeteksi';
      case CaptureState.capturing:
      case CaptureState.done:
        return 'Berhasil';
      default:
        return '';
    }
  }

  String get _subtitle {
    if (_fsm.state == CaptureState.searching) {
      switch (_last.alignment) {
        case FaceAlignment.tooSmall:
          return 'Wajah terlalu jauh dari kamera';
        case FaceAlignment.tooBig:
          return 'Wajah terlalu dekat ke kamera';
        case FaceAlignment.offCenter:
          return 'Letakkan wajah tepat di tengah';
        case FaceAlignment.tilted:
          return 'Tatap lurus ke arah kamera';
        default:
          return 'Pastikan wajah terlihat jelas';
      }
    }
    switch (_fsm.state) {
      case CaptureState.aligning:
        return 'Jangan bergerak dulu';
      case CaptureState.promptBlink:
        return 'Kedip sekali untuk verifikasi';
      case CaptureState.retry:
        return 'Kedipkan mata sekali lagi';
      case CaptureState.exhausted:
        return 'Tekan tombol di bawah untuk mengulang';
      case CaptureState.capturing:
      case CaptureState.done:
        return 'Foto wajah tersimpan';
      default:
        return '';
    }
  }

  /// Target ring color for a given state. The painter lerps toward this.
  Color _targetRingColor(CaptureState state) {
    switch (state) {
      case CaptureState.aligning:
        return AppColors.accent; // amber: locking on
      case CaptureState.promptBlink:
      case CaptureState.capturing:
      case CaptureState.done:
        return AppColors.success; // green: success path
      case CaptureState.exhausted:
        return AppColors.danger; // red: failed
      case CaptureState.retry:
        return AppColors.accent;
      default:
        return _kNeutral; // searching / idle
    }
  }

  Color get _actionColor {
    switch (widget.pendingAction) {
      case AttendanceType.masuk:
        return AppColors.success;
      case AttendanceType.pulang:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String get _actionLabel {
    switch (widget.pendingAction) {
      case AttendanceType.masuk:
        return 'VERIFIKASI MASUK';
      case AttendanceType.pulang:
        return 'VERIFIKASI PULANG';
      default:
        return 'VERIFIKASI WAJAH';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const _CameraSurface(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
    }
    if (_error != null) {
      return _CameraSurface(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_rounded,
                    color: Colors.white70, size: 40),
                const SizedBox(height: 14),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    final captured = _capturedBytes;
    final isFront = CameraService.instance.cameraDescription?.lensDirection ==
        CameraLensDirection.front;

    return _CameraSurface(
      child: Stack(fit: StackFit.expand, children: [
        // 1. Live preview (or frozen captured frame).
        if (captured != null)
          Image.memory(captured, fit: BoxFit.cover)
        else
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _previewSize.width,
              height: _previewSize.height,
              child: CameraService.instance.getPreviewWidget(),
            ),
          ),

        // 2. Animated scrim + guide oval + progress ring + face tracking.
        // Repaints on controller ticks; the face box rides setState ticks.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _painterRepaint,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _FaceGuidePainter(
                ringColor: _currentRingColor(),
                state: _fsm.state,
                progress: _progress.value,
                sweep: _sweep.value,
                breathe: _breathe.value,
                lock: _lock.value,
                faceBox: _last.hasFace ? _last.boundingBox : null,
                frameSize: _previewSize,
                mirrorX: isFront,
                captured: captured != null,
              ),
            ),
          ),
        ),

        // 3. Success checkmark — spring scale-in on capture/done.
        if (_fsm.state == CaptureState.capturing ||
            _fsm.state == CaptureState.done)
          Center(
            child: _SuccessCheck(controller: _success),
          ),

        // 4. Top action title pill.
        Positioned(
          top: 14,
          left: 16,
          right: 16,
          child: _ActionTitlePill(label: _actionLabel, color: _actionColor),
        ),

        // 5. Bottom status panel — big headline + helper subtitle. The accent
        // glides with the ring color via _colorGlide.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: AnimatedBuilder(
            animation: _colorGlide,
            builder: (context, _) => _StatusPanel(
              headline: _headline,
              subtitle: _subtitle,
              accent: _currentRingColor(),
              state: _fsm.state,
              onRetry: _fsm.state == CaptureState.exhausted
                ? () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _renderedState = CaptureState.searching;
                      _fsm.reset();
                    });
                    _animateRingColorTo(_kNeutral);
                    _progress.animateTo(0, curve: Curves.easeOut);
                  }
                  : null,
              onCancel: widget.onCancel,
            ),
          ),
        ),
      ]),
    );
  }

  Size get _previewSize {
    final size = CameraService.instance.controller?.value.previewSize;
    if (size == null) return const Size(720, 1280);
    return Size(size.height, size.width);
  }
}

// ════════════════════════════════════════════════════════════════════
//  Camera surface — rounded, black-backed 3:4 frame.
// ════════════════════════════════════════════════════════════════════

class _CameraSurface extends StatelessWidget {
  final Widget child;
  const _CameraSurface({required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(aspectRatio: 3 / 4, child: child),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  Top pill — the action being verified (MASUK / PULANG).
// ════════════════════════════════════════════════════════════════════

class _ActionTitlePill extends StatelessWidget {
  final String label;
  final Color color;
  const _ActionTitlePill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_user_rounded, color: color, size: 13),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4)),
            ]),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  Bottom status panel — headline + subtitle, with optional retry / cancel.
//  Animates content swaps so state changes feel deliberate.
// ════════════════════════════════════════════════════════════════════

class _StatusPanel extends StatelessWidget {
  final String headline;
  final String subtitle;
  final Color accent;
  final CaptureState state;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const _StatusPanel({
    required this.headline,
    required this.subtitle,
    required this.accent,
    required this.state,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final showCheck = state == CaptureState.capturing || state == CaptureState.done;
    final showError = state == CaptureState.exhausted;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusLeadingIcon(
                  showCheck: showCheck,
                  showError: showError,
                  accent: accent,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      headline,
                      key: ValueKey<String>(headline),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                subtitle,
                key: ValueKey<String>(subtitle),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black45)],
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
                child: const Text('Batal',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small circular leading badge next to the headline. Shows a check on
/// success, an alert on failure, otherwise a face icon tinted to the accent.
class _StatusLeadingIcon extends StatelessWidget {
  final bool showCheck;
  final bool showError;
  final Color accent;
  const _StatusLeadingIcon({
    required this.showCheck,
    required this.showError,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color tint;
    if (showCheck) {
      icon = Icons.check_circle_rounded;
      tint = AppColors.success;
    } else if (showError) {
      icon = Icons.error_rounded;
      tint = AppColors.danger;
    } else {
      icon = Icons.face_retouching_natural_rounded;
      tint = accent;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 1),
      ),
      child: Icon(icon, color: tint, size: 18),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Success checkmark — spring scale + fade, centered over the oval.
// ════════════════════════════════════════════════════════════════════

class _SuccessCheck extends StatelessWidget {
  final AnimationController controller;
  const _SuccessCheck({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: controller, curve: Curves.elasticOut);
    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.4, end: 1).animate(scale),
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.45),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  The painter — scrim cut-out, breathing guide, progress ring,
//  scanning sweep, alignment-lock ripple, and live face tracking.
//  Driven by AnimationControllers; no per-frame allocation beyond Paints.
// ════════════════════════════════════════════════════════════════════

class _FaceGuidePainter extends CustomPainter {
  final Color ringColor;
  final CaptureState state;
  final double progress; // 0..1 ring fill
  final double sweep; // 0..1 rotation phase
  final double breathe; // 0..1 pulse phase
  final double lock; // 0..1 one-shot lock ripple
  final Rect? faceBox;
  final Size? frameSize;
  final bool mirrorX;
  final bool captured;

  const _FaceGuidePainter({
    required this.ringColor,
    required this.state,
    required this.progress,
    required this.sweep,
    required this.breathe,
    required this.lock,
    required this.mirrorX,
    required this.captured,
    this.faceBox,
    this.frameSize,
  });

  static const Color _scrim = Color(0xFF0B0B0F);

  Rect _ovalRect(Size size) {
    final width = size.width * 0.70;
    final height = size.height * 0.58;
    final left = (size.width - width) / 2;
    final top = size.height * 0.13;
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Maps the detected face rect from camera-frame coords into screen coords,
  /// assuming the preview was rendered with BoxFit.cover. Identical mapping to
  /// the original implementation so tracking stays accurate.
  Rect? _faceBoxOnScreen(Size canvasSize) {
    final box = faceBox;
    final frame = frameSize;
    if (box == null || frame == null || frame.width <= 0 || frame.height <= 0) {
      return null;
    }
    final scale = math.max(
      canvasSize.width / frame.width,
      canvasSize.height / frame.height,
    );
    final scaledW = frame.width * scale;
    final scaledH = frame.height * scale;
    final xOffset = (canvasSize.width - scaledW) / 2;
    final yOffset = (canvasSize.height - scaledH) / 2;

    double left = box.left * scale + xOffset;
    double top = box.top * scale + yOffset;
    double right = box.right * scale + xOffset;
    double bottom = box.bottom * scale + yOffset;

    if (mirrorX) {
      final l = canvasSize.width - right;
      final r = canvasSize.width - left;
      left = l;
      right = r;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseOval = _ovalRect(size);

    // Gentle breathing while idle/searching so the guide feels alive; locks
    // to a stable size once we are aligning or beyond.
    final pulse = (state == CaptureState.searching)
        ? 1.0 + (math.sin(breathe * math.pi) * 0.012)
        : 1.0;
    final oval = Rect.fromCenter(
      center: baseOval.center,
      width: baseOval.width * pulse,
      height: baseOval.height * pulse,
    );

    // ── 1. Scrim with the oval punched out (vignette focus) ──────────
    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    // Slightly stronger scrim once a face locks, to spotlight the subject.
    final scrimAlpha = state == CaptureState.searching ? 0.52 : 0.6;
    canvas.drawPath(maskPath, Paint()..color = _scrim.withValues(alpha: scrimAlpha));

    // Soft inner feather just inside the oval edge so the cut-out isn't harsh.
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = _scrim.withValues(alpha: scrimAlpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final center = oval.center;
    final radius = (oval.width / 2);

    // ── 2. Base guide track (faint full ring under the progress arc) ─
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    // ── 3. Rotating scanning sweep (only while searching) ────────────
    if (state == CaptureState.searching && !captured) {
      final sweepPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: GradientRotation(sweep * 2 * math.pi),
          colors: [
            ringColor.withValues(alpha: 0.0),
            ringColor.withValues(alpha: 0.0),
            ringColor.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(oval);
      canvas.drawOval(oval.deflate(1), sweepPaint);
    }

    // ── 4. Progress ring — fills clockwise from top as the user holds ─
    if (progress > 0.001) {
      // Glow underlay for a premium "lit" ring.
      canvas.drawArc(
        oval,
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = ringColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawArc(
        oval,
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = ringColor,
      );
      // Leading dot at the tip of the progress arc.
      if (progress < 0.999) {
        final tipAngle = -math.pi / 2 + progress * 2 * math.pi;
        final tip = Offset(
          center.dx + radius * math.cos(tipAngle),
          center.dy + (oval.height / 2) * math.sin(tipAngle),
        );
        canvas.drawCircle(tip, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          tip,
          7,
          Paint()
            ..color = ringColor.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // ── 5. Alignment-lock ripple (one-shot, on searching→aligning) ───
    if (lock > 0.001 && lock < 0.999) {
      final rippleR = radius * (1.0 + lock * 0.22);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: rippleR * 2,
          height: (oval.height / 2) * (1.0 + lock * 0.22) * 2,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ringColor.withValues(alpha: (1 - lock) * 0.7),
      );
    }

    // ── 6. Live face tracking — subtle bracket lock on the real face ─
    final tracked = _faceBoxOnScreen(size);
    if (tracked != null && !captured) {
      _drawCornerBrackets(canvas, tracked, ringColor.withValues(alpha: 0.9));
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect r, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    final len = math.min(r.width, r.height) * 0.16;
    // top-left
    canvas.drawLine(r.topLeft, r.topLeft + Offset(len, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, len), paint);
    // top-right
    canvas.drawLine(r.topRight, r.topRight + Offset(-len, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, len), paint);
    // bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(len, 0), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -len), paint);
    // bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-len, 0), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -len), paint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter old) =>
      old.ringColor != ringColor ||
      old.state != state ||
      old.progress != progress ||
      old.sweep != sweep ||
      old.breathe != breathe ||
      old.lock != lock ||
      old.faceBox != faceBox ||
      old.mirrorX != mirrorX ||
      old.captured != captured ||
      old.frameSize != frameSize;
}

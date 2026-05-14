import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, WriteBuffer;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/attendance_log.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';

class CameraFacePreview extends StatefulWidget {
  final ValueChanged<Uint8List> onPhotoCaptured;
  final AttendanceType pendingAction;

  const CameraFacePreview({
    super.key,
    required this.onPhotoCaptured,
    this.pendingAction = AttendanceType.masuk,
  });

  @override
  State<CameraFacePreview> createState() => _CameraFacePreviewState();
}

class _CameraFacePreviewState extends State<CameraFacePreview>
    with SingleTickerProviderStateMixin {
  FaceDetectionResult _faceResult = const FaceDetectionResult.empty();
  Uint8List? _capturedBytes;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initializing = true;
  bool _processingFrame = false;
  bool _capturing = false;
  String? _error;

  late final AnimationController _holdCtrl;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: AppConstants.attendancePhotoStableFaceMs,
      ),
    );
    _holdCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(_capturePhoto());
      }
    });
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
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
    } catch (error) {
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
    unawaited(_processCameraImage(image));
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final result =
          await FaceDetectionService.instance.processImage(inputImage);
      if (!mounted || _capturing) return;

      setState(() => _faceResult = result);

      if (result.isValid) {
        if (_holdCtrl.status != AnimationStatus.forward &&
            _holdCtrl.status != AnimationStatus.completed) {
          _holdCtrl.forward();
        }
      } else {
        if (_holdCtrl.status != AnimationStatus.dismissed) {
          _holdCtrl.reset();
        }
      }
    } catch (_) {
      if (_holdCtrl.status != AnimationStatus.dismissed) {
        _holdCtrl.reset();
      }
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _capturePhoto() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final bytes = await CameraService.instance.capturePhoto();
      if (!mounted) return;
      setState(() => _capturedBytes = bytes);
      await Future<void>.delayed(
        const Duration(milliseconds: AppConstants.attendancePhotoPreviewMs),
      );
      if (mounted) widget.onPhotoCaptured(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Foto gagal diambil';
      });
      _holdCtrl.reset();
      unawaited(_initialize());
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = CameraService.instance.controller;
    final camera = CameraService.instance.cameraDescription;
    if (controller == null || camera == null) return null;

    final rotation =
        _inputImageRotation(camera, controller.value.deviceOrientation);
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
    final captured = _capturedBytes;
    if (_initializing) {
      return const _CameraSurface(
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null) {
      return _CameraSurface(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return _CameraSurface(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
          AnimatedBuilder(
            animation: _holdCtrl,
            builder: (_, __) {
              return CustomPaint(
                painter: _OvalGuidePainter(
                  valid: _faceResult.isValid,
                  capturing: _capturing,
                  progress: _holdCtrl.value,
                  successColor: AppColors.success,
                ),
              );
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _ActionTitlePill(
              label: _actionLabel,
              color: _actionColor,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _GuidancePill(
              valid: _faceResult.isValid,
              capturing: _capturing,
            ),
          ),
        ],
      ),
    );
  }

  Size get _previewSize {
    final size = CameraService.instance.controller?.value.previewSize;
    if (size == null) return const Size(720, 1280);
    return Size(size.height, size.width);
  }
}

class _CameraSurface extends StatelessWidget {
  final Widget child;

  const _CameraSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: child,
        ),
      ),
    );
  }
}

class _ActionTitlePill extends StatelessWidget {
  final String label;
  final Color color;

  const _ActionTitlePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidancePill extends StatelessWidget {
  final bool valid;
  final bool capturing;

  const _GuidancePill({
    required this.valid,
    required this.capturing,
  });

  @override
  Widget build(BuildContext context) {
    final color = valid ? AppColors.success : Colors.white;
    final text = capturing
        ? 'Foto diambil...'
        : valid
            ? 'Tahan posisi wajah'
            : 'Posisikan wajah di dalam lingkaran';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              valid
                  ? Icons.check_circle_rounded
                  : Icons.face_retouching_natural_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  final bool valid;
  final bool capturing;
  final double progress;
  final Color successColor;

  const _OvalGuidePainter({
    required this.valid,
    required this.capturing,
    required this.progress,
    required this.successColor,
  });

  Rect _ovalRect(Size size) {
    final width = size.width * 0.72;
    final height = size.height * 0.50;
    final left = (size.width - width) / 2;
    final top = size.height * 0.10;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final oval = _ovalRect(size);

    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final borderColor = valid
        ? successColor.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.85);
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = valid ? 4.5 : 3.0
        ..color = borderColor,
    );

    if (valid && progress > 0) {
      canvas.drawArc(
        oval.deflate(2),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = successColor,
      );
    }

    if (capturing) {
      canvas.drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = successColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter oldDelegate) {
    return oldDelegate.valid != valid ||
        oldDelegate.capturing != capturing ||
        oldDelegate.progress != progress ||
        oldDelegate.successColor != successColor;
  }
}

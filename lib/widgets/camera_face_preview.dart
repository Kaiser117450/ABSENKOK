import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, WriteBuffer;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';

class CameraFacePreview extends StatefulWidget {
  final ValueChanged<Uint8List> onPhotoCaptured;

  const CameraFacePreview({
    super.key,
    required this.onPhotoCaptured,
  });

  @override
  State<CameraFacePreview> createState() => _CameraFacePreviewState();
}

class _CameraFacePreviewState extends State<CameraFacePreview> {
  FaceDetectionResult _faceResult = const FaceDetectionResult.empty();
  Size? _imageSize;
  Uint8List? _capturedBytes;
  DateTime? _validFaceSince;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initializing = true;
  bool _processingFrame = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(CameraService.instance.stopImageStreamIfNeeded());
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
      final imageSize = inputImage.metadata?.size;
      if (!mounted || _capturing) return;

      setState(() {
        _faceResult = result;
        _imageSize = imageSize;
      });

      if (result.isValid) {
        _validFaceSince ??= DateTime.now();
        final stableMs =
            DateTime.now().difference(_validFaceSince!).inMilliseconds;
        if (stableMs >= AppConstants.attendancePhotoStableFaceMs) {
          await _capturePhoto();
        }
      } else {
        _validFaceSince = null;
      }
    } catch (_) {
      _validFaceSince = null;
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
        _validFaceSince = null;
        _error = 'Foto gagal diambil';
      });
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
          child: Text(
            _error!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
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
          CustomPaint(
            painter: _FaceOverlayPainter(
              result: _faceResult,
              imageSize: _imageSize,
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

class _GuidancePill extends StatelessWidget {
  final bool valid;
  final bool capturing;

  const _GuidancePill({
    required this.valid,
    required this.capturing,
  });

  @override
  Widget build(BuildContext context) {
    final color = valid ? AppColors.success : AppColors.danger;
    final text = capturing
        ? 'Mengambil foto'
        : valid
            ? 'Wajah terdeteksi'
            : 'Arahkan wajah ke kamera';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              valid
                  ? Icons.face_retouching_natural_rounded
                  : Icons.face_rounded,
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

class _FaceOverlayPainter extends CustomPainter {
  final FaceDetectionResult result;
  final Size? imageSize;

  const _FaceOverlayPainter({
    required this.result,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final box = result.boundingBox;
    final sourceSize = imageSize;
    if (box == null || sourceSize == null) return;

    final scale = math.max(
      size.width / sourceSize.width,
      size.height / sourceSize.height,
    );
    final dx = (size.width - sourceSize.width * scale) / 2;
    final dy = (size.height - sourceSize.height * scale) / 2;
    final rect = Rect.fromLTRB(
      box.left * scale + dx,
      box.top * scale + dy,
      box.right * scale + dx,
      box.bottom * scale + dy,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = result.isValid ? AppColors.success : AppColors.danger;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) {
    return oldDelegate.result != result || oldDelegate.imageSize != imageSize;
  }
}

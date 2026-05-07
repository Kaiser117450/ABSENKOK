import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraService {
  CameraService._();

  static final CameraService instance = CameraService._();

  CameraController? _controller;
  Future<void>? _initializeFuture;

  CameraController? get controller => _controller;
  CameraDescription? get cameraDescription => _controller?.description;

  bool get isInitialized => _controller?.value.isInitialized == true;

  Future<void> initialize() {
    if (isInitialized) return Future<void>.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Some front cameras do not expose flash mode.
      }

      _controller = controller;
    } catch (_) {
      _initializeFuture = null;
      rethrow;
    }
  }

  Future<void> stopImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;
    await controller.stopImageStream();
  }

  Future<Uint8List> capturePhoto() async {
    await initialize();
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Camera is not initialized');
    }
    await stopImageStreamIfNeeded();
    final file = await controller.takePicture();
    return file.readAsBytes();
  }

  Widget getPreviewWidget() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return CameraPreview(controller);
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    await controller?.dispose();
  }
}

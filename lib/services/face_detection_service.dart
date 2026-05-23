import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';

enum FaceAlignment { absent, tooSmall, tooBig, offCenter, tilted, aligned }

class FaceDetectionResult {
  final bool hasFace;
  final int faceCount;
  final Rect? boundingBox;
  final double? headEulerAngleY;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final FaceAlignment alignment;

  const FaceDetectionResult({
    required this.hasFace,
    required this.faceCount,
    required this.alignment,
    this.boundingBox,
    this.headEulerAngleY,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  const FaceDetectionResult.empty()
      : hasFace = false,
        faceCount = 0,
        boundingBox = null,
        headEulerAngleY = null,
        leftEyeOpen = null,
        rightEyeOpen = null,
        alignment = FaceAlignment.absent;

  bool get bothEyesClosed =>
      (leftEyeOpen ?? 1) < AppConstants.attendancePhotoEyeClosedThreshold &&
      (rightEyeOpen ?? 1) < AppConstants.attendancePhotoEyeClosedThreshold;

  bool get bothEyesOpen =>
      (leftEyeOpen ?? 0) > AppConstants.attendancePhotoEyeOpenThreshold &&
      (rightEyeOpen ?? 0) > AppConstants.attendancePhotoEyeOpenThreshold;
}

class FaceDetectionService {
  FaceDetectionService._();

  static final FaceDetectionService instance = FaceDetectionService._();

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  Future<FaceDetectionResult> processImage(InputImage inputImage) async {
    final faces = await _detector.processImage(inputImage);
    if (faces.isEmpty) return const FaceDetectionResult.empty();

    final face = faces.first;
    final frameSize = inputImage.metadata?.size;
    final alignment = _resolveAlignment(face, frameSize, faces.length);

    return FaceDetectionResult(
      hasFace: true,
      faceCount: faces.length,
      boundingBox: face.boundingBox,
      headEulerAngleY: face.headEulerAngleY,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      alignment: alignment,
    );
  }

  FaceAlignment _resolveAlignment(Face face, Size? frame, int faceCount) {
    if (faceCount != 1) return FaceAlignment.absent;
    final tilt = face.headEulerAngleY?.abs() ?? 0;
    if (tilt > AppConstants.attendancePhotoMaxHeadEulerY) {
      return FaceAlignment.tilted;
    }
    if (frame == null) return FaceAlignment.aligned;

    final widthRatio = face.boundingBox.width / frame.width;
    if (widthRatio < AppConstants.attendancePhotoOvalFillMin) {
      return FaceAlignment.tooSmall;
    }
    if (widthRatio > AppConstants.attendancePhotoOvalFillMax) {
      return FaceAlignment.tooBig;
    }

    final faceCenterX = face.boundingBox.center.dx;
    final frameCenterX = frame.width / 2;
    final centerOffset = (faceCenterX - frameCenterX).abs() / frame.width;
    if (centerOffset > 0.15) return FaceAlignment.offCenter;

    return FaceAlignment.aligned;
  }

  Future<void> close() => _detector.close();
}

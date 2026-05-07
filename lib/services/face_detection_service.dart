import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/constants.dart';

class FaceDetectionResult {
  final bool hasFace;
  final int faceCount;
  final Rect? boundingBox;
  final double? headEulerAngleY;
  final bool isValid;

  const FaceDetectionResult({
    required this.hasFace,
    required this.faceCount,
    this.boundingBox,
    this.headEulerAngleY,
    required this.isValid,
  });

  const FaceDetectionResult.empty()
      : hasFace = false,
        faceCount = 0,
        boundingBox = null,
        headEulerAngleY = null,
        isValid = false;
}

class FaceDetectionService {
  FaceDetectionService._();

  static final FaceDetectionService instance = FaceDetectionService._();

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  Future<FaceDetectionResult> processImage(InputImage inputImage) async {
    final faces = await _detector.processImage(inputImage);
    if (faces.isEmpty) {
      return const FaceDetectionResult.empty();
    }

    final face = faces.first;
    final frameSize = inputImage.metadata?.size;
    final eulerY = face.headEulerAngleY;
    final hasSingleFace = faces.length == 1;
    final isFrontFacing = eulerY == null ||
        eulerY.abs() < AppConstants.attendancePhotoMaxHeadEulerY;
    final hasLargeEnoughFace = frameSize == null ||
        (face.boundingBox.width >=
                frameSize.width *
                    AppConstants.attendancePhotoMinFaceFrameRatio &&
            face.boundingBox.height >=
                frameSize.height *
                    AppConstants.attendancePhotoMinFaceFrameRatio);

    return FaceDetectionResult(
      hasFace: true,
      faceCount: faces.length,
      boundingBox: face.boundingBox,
      headEulerAngleY: eulerY,
      isValid: hasSingleFace && isFrontFacing && hasLargeEnoughFace,
    );
  }

  Future<void> close() => _detector.close();
}

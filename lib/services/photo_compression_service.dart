import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/constants.dart';

class PhotoCompressionService {
  PhotoCompressionService._();

  static Uint8List compressAndResize(Uint8List rawBytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(rawBytes);
    } catch (_) {
      return rawBytes;
    }
    if (decoded == null) {
      return rawBytes;
    }

    final longestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final maxSide = AppConstants.attendancePhotoMaxDimensionPx;
    final output = longestSide > maxSide
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
          )
        : decoded;

    return Uint8List.fromList(
      img.encodeJpg(
        output,
        quality: AppConstants.attendancePhotoJpegQuality,
      ),
    );
  }
}

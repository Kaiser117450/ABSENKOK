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

    // Bake EXIF orientation into the pixels so devices that store rotation as
    // metadata (rather than rotating the buffer) don't yield sideways/upside
    // down selfies. Front-camera mirroring is untouched. If the source had no
    // orientation tag this is a no-op.
    final oriented = img.bakeOrientation(decoded);

    final longestSide =
        oriented.width > oriented.height ? oriented.width : oriented.height;
    final maxSide = AppConstants.attendancePhotoMaxDimensionPx;
    final output = longestSide > maxSide
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? maxSide : null,
            height: oriented.height > oriented.width ? maxSide : null,
          )
        : oriented;

    return Uint8List.fromList(
      img.encodeJpg(
        output,
        quality: AppConstants.attendancePhotoJpegQuality,
      ),
    );
  }
}

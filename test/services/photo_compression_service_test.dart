import 'dart:typed_data';

import 'package:absensi_enakko_flutter/core/constants.dart';
import 'package:absensi_enakko_flutter/services/photo_compression_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PhotoCompressionService', () {
    test('resizes the longest side to the beta maximum and returns JPEG bytes',
        () {
      final source = img.Image(width: 1200, height: 800);
      img.fill(source, color: img.ColorRgb8(220, 40, 30));
      final rawBytes = Uint8List.fromList(img.encodePng(source));

      final compressed = PhotoCompressionService.compressAndResize(rawBytes);
      final decoded = img.decodeJpg(compressed);

      expect(decoded, isNotNull);
      expect(decoded!.width, AppConstants.attendancePhotoMaxDimensionPx);
      expect(decoded.height, 427);
    });

    test('returns original bytes when image decoding fails', () {
      final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final compressed = PhotoCompressionService.compressAndResize(rawBytes);

      expect(compressed, rawBytes);
    });
  });
}

import 'package:flutter/material.dart';

/// Canonical shift bands for Phase 55's band-first schedule policy.
enum ShiftBand {
  pagi('PAGI', 'Pagi', 7, 0),
  siang('SIANG', 'Siang', 10, 0),
  sore('SORE', 'Sore', 15, 0),
  libur('LIBUR', 'Libur', null, null);

  const ShiftBand(
    this.storageValue,
    this.label,
    this.lateCutoffHour,
    this.lateCutoffMinute,
  );

  final String storageValue;
  final String label;
  final int? lateCutoffHour;
  final int? lateCutoffMinute;

  bool get isDayOff => this == ShiftBand.libur;

  TimeOfDay? get lateCutoff {
    if (lateCutoffHour == null || lateCutoffMinute == null) {
      return null;
    }
    return TimeOfDay(hour: lateCutoffHour!, minute: lateCutoffMinute!);
  }

  static ShiftBand parse(String? raw) {
    return tryParse(raw) ?? ShiftBand.pagi;
  }

  static ShiftBand? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized =
        raw.trim().toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (normalized.isEmpty) {
      return null;
    }

    switch (normalized) {
      case 'PAGI':
      case 'MORNING':
        return ShiftBand.pagi;
      case 'SIANG':
      case 'AFTERNOON':
        return ShiftBand.siang;
      case 'SORE':
      case 'EVENING':
        return ShiftBand.sore;
      case 'LIBUR':
      case 'OFF':
      case 'DAYOFF':
      case 'HARILIBUR':
        return ShiftBand.libur;
      default:
        return null;
    }
  }
}

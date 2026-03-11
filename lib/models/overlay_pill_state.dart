import 'dart:convert';

enum OverlayPillMode { idle, event }

class OverlayPillState {
  static const String defaultOutlet = 'Absensi Enakko';
  static const String defaultTime = '--:--';
  static const String defaultAttendanceType = 'masuk';
  static const String defaultAccentHex = '#22C55E';

  const OverlayPillState({
    required this.mode,
    required this.outlet,
    required this.time,
    required this.attendanceType,
    required this.accentHex,
    this.eventUntilEpochMs = 0,
    this.expanded = true,
    this.badgeEmoji = '',
    this.displayLabel = '',
  });

  factory OverlayPillState.defaults() {
    return const OverlayPillState(
      mode: OverlayPillMode.idle,
      outlet: defaultOutlet,
      time: defaultTime,
      attendanceType: defaultAttendanceType,
      accentHex: defaultAccentHex,
      eventUntilEpochMs: 0,
      expanded: true,
      badgeEmoji: '',
      displayLabel: '',
    );
  }

  final OverlayPillMode mode;
  final String outlet;
  final String time;
  final String attendanceType;
  final String accentHex;
  final int eventUntilEpochMs;
  final bool expanded;
  final String badgeEmoji;
  final String displayLabel;

  factory OverlayPillState.fromRaw(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return OverlayPillState.defaults();
    }

    try {
      if (normalized.startsWith('{')) {
        final decoded = jsonDecode(normalized);
        if (decoded is Map<String, dynamic>) {
          return OverlayPillState.fromMap(decoded);
        }
      }
    } catch (_) {
      return OverlayPillState.defaults();
    }

    return OverlayPillState._fromLegacyPayload(normalized);
  }

  factory OverlayPillState.fromMap(Map<String, dynamic> map) {
    final modeValue = (map['mode'] ?? '').toString();
    final parsedMode =
        modeValue == 'event' ? OverlayPillMode.event : OverlayPillMode.idle;

    final outletValue = (map['outlet'] ?? '').toString().trim();
    final timeValue = (map['time'] ?? '').toString().trim();
    final attendanceValue = (map['attendanceType'] ?? '').toString().trim();
    final accentValue = (map['accentHex'] ?? '').toString().trim();

    final parsedEventUntil = _toInt(map['eventUntilEpochMs']);
    final parsedExpanded = _toBool(map['expanded']);
    final badgeEmojiValue = (map['badgeEmoji'] ?? '').toString().trim();
    final displayLabelValue = (map['displayLabel'] ?? '').toString().trim();

    return OverlayPillState(
      mode: parsedMode,
      outlet: outletValue.isEmpty ? defaultOutlet : outletValue,
      time: timeValue.isEmpty ? defaultTime : timeValue,
      attendanceType: attendanceValue.isEmpty
          ? defaultAttendanceType
          : attendanceValue,
      accentHex: accentValue.isEmpty ? defaultAccentHex : accentValue,
      eventUntilEpochMs: parsedEventUntil ?? 0,
      expanded: parsedExpanded ?? true,
      badgeEmoji: badgeEmojiValue,
      displayLabel: displayLabelValue,
    );
  }

  static OverlayPillState _fromLegacyPayload(String raw) {
    final parts = raw.split('|');
    final outletValue = parts.isNotEmpty ? parts[0].trim() : '';
    final timeValue = parts.length > 1 ? parts[1].trim() : '';

    return OverlayPillState(
      mode: OverlayPillMode.idle,
      outlet: outletValue.isEmpty ? defaultOutlet : outletValue,
      time: timeValue.isEmpty ? defaultTime : timeValue,
      attendanceType: defaultAttendanceType,
      accentHex: defaultAccentHex,
      eventUntilEpochMs: 0,
      expanded: true,
      badgeEmoji: '',
      displayLabel: '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'v': 1,
      'mode': mode.name,
      'outlet': outlet,
      'time': time,
      'attendanceType': attendanceType,
      'accentHex': accentHex,
      'eventUntilEpochMs': eventUntilEpochMs,
      'expanded': expanded,
      'badgeEmoji': badgeEmoji,
      'displayLabel': displayLabel,
    };
  }

  String toWirePayload() => jsonEncode(toMap());

  bool isEventExpiredAt(DateTime at) {
    if (mode != OverlayPillMode.event) return false;
    if (eventUntilEpochMs <= 0) return false;
    return eventUntilEpochMs <= at.millisecondsSinceEpoch;
  }

  bool isEventExpiredNow() => isEventExpiredAt(DateTime.now());

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lowered = value.toLowerCase();
      if (lowered == 'true') return true;
      if (lowered == 'false') return false;
    }
    return null;
  }
}

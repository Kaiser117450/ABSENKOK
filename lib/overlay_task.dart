import 'dart:async';

import 'package:absensi_enakko_flutter/models/attendance_log.dart';
import 'package:absensi_enakko_flutter/models/overlay_pill_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: KioskOverlayUI(),
    );
  }
}

class KioskOverlayUI extends StatefulWidget {
  const KioskOverlayUI({
    super.key,
    this.dataStream,
    this.now = DateTime.now,
    this.clockTick = const Duration(seconds: 30),
    this.staleThreshold = const Duration(minutes: 2),
    this.autoCollapseDelay = const Duration(seconds: 3),
  });

  final Stream<dynamic>? dataStream;
  final DateTime Function() now;
  final Duration clockTick;
  final Duration staleThreshold;
  final Duration autoCollapseDelay;

  @override
  State<KioskOverlayUI> createState() => _KioskOverlayUIState();
}

class _KioskOverlayUIState extends State<KioskOverlayUI> {
  OverlayPillState _currentState = OverlayPillState.defaults();
  OverlayPillState _idleState = OverlayPillState.defaults();
  bool _isExpanded = true;

  Timer? _clockTimer;
  Timer? _eventResetTimer;
  Timer? _autoCollapseTimer;
  StreamSubscription<dynamic>? _dataSub;
  DateTime? _lastPayloadAt;

  static const double _expandedHeight = 56;
  static const double _collapsedHeight = 38;

  @override
  void initState() {
    super.initState();
    _applyLocalClock(force: true);

    _clockTimer = Timer.periodic(widget.clockTick, (_) {
      if (mounted) {
        _onClockTick();
      }
    });

    final stream = widget.dataStream ?? FlutterOverlayWindow.overlayListener;
    _dataSub = stream.listen((raw) {
      if (raw == null || !mounted) {
        return;
      }
      final incoming = OverlayPillState.fromRaw(raw.toString());
      _lastPayloadAt = widget.now();
      _applyIncomingState(incoming);
    });

    _autoCollapseTimer = Timer(widget.autoCollapseDelay, () {
      if (mounted) {
        setState(() => _isExpanded = false);
      }
    });
  }

  void _onClockTick() {
    final now = widget.now();
    if (_currentState.mode == OverlayPillMode.event &&
        _currentState.isEventExpiredAt(now)) {
      _revertEventToIdle(useLocalClock: true);
      return;
    }
    _applyLocalClock();
  }

  void _applyIncomingState(OverlayPillState incoming) {
    _eventResetTimer?.cancel();
    _eventResetTimer = null;

    if (incoming.mode == OverlayPillMode.event) {
      if (incoming.isEventExpiredAt(widget.now())) {
        _revertEventToIdle(useLocalClock: true);
        return;
      }

      setState(() {
        _currentState = _copyState(
          incoming,
          time: _resolvedTime(incoming.time),
        );
      });
      _scheduleEventReset(_currentState);
      return;
    }

    final normalizedIdle = _normalizeIdleState(incoming);
    setState(() {
      _idleState = normalizedIdle;
      _currentState = normalizedIdle;
    });
  }

  void _scheduleEventReset(OverlayPillState eventState) {
    if (eventState.eventUntilEpochMs <= 0) {
      return;
    }
    final nowMs = widget.now().millisecondsSinceEpoch;
    final delayMs = eventState.eventUntilEpochMs - nowMs;
    if (delayMs <= 0) {
      _revertEventToIdle(useLocalClock: true);
      return;
    }
    _eventResetTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _revertEventToIdle(useLocalClock: true);
      }
    });
  }

  void _revertEventToIdle({required bool useLocalClock}) {
    _eventResetTimer?.cancel();
    _eventResetTimer = null;
    final fallbackTime =
        useLocalClock ? _formatTime(widget.now()) : _idleState.time;
    setState(() {
      _idleState = _copyState(
        _idleState,
        mode: OverlayPillMode.idle,
        eventUntilEpochMs: 0,
        time: _resolvedTime(fallbackTime),
      );
      _currentState = _idleState;
    });
  }

  void _applyLocalClock({bool force = false}) {
    final now = widget.now();
    final isStale = _lastPayloadAt == null ||
        now.difference(_lastPayloadAt!) > widget.staleThreshold;
    final hasMissingTime = _currentState.time.trim().isEmpty ||
        _currentState.time == OverlayPillState.defaultTime;
    if (!force && !isStale && !hasMissingTime) {
      return;
    }

    final localTime = _formatTime(now);
    setState(() {
      _idleState = _copyState(
        _idleState,
        mode: OverlayPillMode.idle,
        eventUntilEpochMs: 0,
        time: localTime,
      );
      if (_currentState.mode == OverlayPillMode.idle) {
        _currentState = _copyState(
          _currentState,
          mode: OverlayPillMode.idle,
          eventUntilEpochMs: 0,
          time: localTime,
        );
      }
    });
  }

  OverlayPillState _normalizeIdleState(OverlayPillState state) {
    return _copyState(
      state,
      mode: OverlayPillMode.idle,
      eventUntilEpochMs: 0,
      time: _resolvedTime(state.time),
    );
  }

  OverlayPillState _copyState(
    OverlayPillState source, {
    OverlayPillMode? mode,
    String? outlet,
    String? time,
    String? attendanceType,
    String? accentHex,
    int? eventUntilEpochMs,
    bool? expanded,
  }) {
    return OverlayPillState(
      mode: mode ?? source.mode,
      outlet: outlet ?? source.outlet,
      time: time ?? source.time,
      attendanceType: attendanceType ?? source.attendanceType,
      accentHex: accentHex ?? source.accentHex,
      eventUntilEpochMs: eventUntilEpochMs ?? source.eventUntilEpochMs,
      expanded: expanded ?? source.expanded,
    );
  }

  String _resolvedTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty || trimmed == OverlayPillState.defaultTime) {
      return _formatTime(widget.now());
    }
    return trimmed;
  }

  String _formatTime(DateTime now) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  _OverlayVisualStyle _resolveStyle() {
    final attendanceType = AttendanceTypeExt.fromString(
      _currentState.attendanceType.toLowerCase(),
    );
    final accent = _parseAccentHex(_currentState.accentHex, attendanceType.color);
    final modeLabel =
        _currentState.mode == OverlayPillMode.event ? 'Event aktif' : 'Kiosk aktif';

    return _OverlayVisualStyle(
      attendanceLabel: attendanceType.label,
      modeLabel: modeLabel,
      accent: accent,
    );
  }

  Color _parseAccentHex(String rawHex, Color fallback) {
    final normalized = rawHex.trim().replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) {
      return fallback;
    }

    final value =
        normalized.length == 6 ? 'FF$normalized' : normalized.toUpperCase();
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return fallback;
    }
    return Color(parsed);
  }

  Widget _switchTransition(Widget child, Animation<double> animation) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(curved);
    final scale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(curved);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _eventResetTimer?.cancel();
    _autoCollapseTimer?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final expandedWidth = (screenWidth * 0.9).clamp(250.0, 420.0).toDouble();
    final collapsedWidth = (screenWidth * 0.48).clamp(130.0, 220.0).toDouble();
    final style = _resolveStyle();
    final modeOffset = _currentState.mode == OverlayPillMode.event
        ? const Offset(0, -0.01)
        : Offset.zero;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 0),
          child: GestureDetector(
            key: const Key('overlay-pill-root'),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: modeOffset,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                width: _isExpanded ? expandedWidth : collapsedWidth,
                height: _isExpanded ? _expandedHeight : _collapsedHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF51C1C1E),
                      Color(0xED111113),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_isExpanded ? 28 : 22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: style.accent.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: _switchTransition,
                  layoutBuilder: (currentChild, previousChildren) {
                    if (currentChild == null) {
                      return const SizedBox.shrink();
                    }
                    return currentChild;
                  },
                  child: _isExpanded
                      ? _buildExpanded(style)
                      : _buildCollapsed(style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(_OverlayVisualStyle style) {
    return Padding(
      key: ValueKey(
        'expanded-${_currentState.mode.name}-${_currentState.attendanceType}-${_currentState.time}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildLogo(style.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentState.outlet,
                  key: const Key('overlay-pill-outlet'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      key: const Key('overlay-pill-accent'),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: style.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        style.attendanceLabel,
                        key: const Key('overlay-pill-attendance'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        style.modeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTimeChip(style.accent),
        ],
      ),
    );
  }

  Widget _buildCollapsed(_OverlayVisualStyle style) {
    return Padding(
      key: ValueKey(
        'collapsed-${_currentState.mode.name}-${_currentState.attendanceType}-${_currentState.time}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            key: const Key('overlay-pill-accent'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: style.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              style.attendanceLabel,
              key: const Key('overlay-pill-collapsed-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currentState.time,
            key: const Key('overlay-pill-time'),
            style: const TextStyle(
              color: Color(0xFFF4F4F5),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(Color accent) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0.55),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTimeChip(Color accent) {
    return Container(
      key: const Key('overlay-pill-time-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Text(
        _currentState.time,
        key: const Key('overlay-pill-time'),
        style: const TextStyle(
          color: Color(0xFFF4F4F5),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _OverlayVisualStyle {
  const _OverlayVisualStyle({
    required this.attendanceLabel,
    required this.modeLabel,
    required this.accent,
  });

  final String attendanceLabel;
  final String modeLabel;
  final Color accent;
}

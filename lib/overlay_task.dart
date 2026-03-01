import 'dart:async';

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
  StreamSubscription<dynamic>? _dataSub;
  DateTime? _lastPayloadAt;

  static const double _expandedW = 280;
  static const double _expandedH = 60;
  static const double _collapsedW = 110;
  static const double _collapsedH = 36;

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

    Future<void>.delayed(widget.autoCollapseDelay, () {
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
    final fallbackTime = useLocalClock ? _formatTime(widget.now()) : _idleState.time;
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

  @override
  void dispose() {
    _clockTimer?.cancel();
    _eventResetTimer?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 0),
          child: GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 550),
              curve: Curves.elasticOut,
              width: _isExpanded ? _expandedW : _collapsedW,
              height: _isExpanded ? _expandedH : _collapsedH,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isExpanded ? _buildExpanded() : _buildCollapsed(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFCC0000),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentState.outlet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_currentState.attendanceType} • tap NFC',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currentState.time,
            style: const TextStyle(
              color: Color(0xFFAEAEB2),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsed() {
    return Padding(
      key: const ValueKey('collapsed'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.nfc_rounded,
            color: Color(0xFF4ADE80),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            _currentState.time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

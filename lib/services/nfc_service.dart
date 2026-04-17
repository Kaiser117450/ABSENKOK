import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

import '../core/constants.dart';

/// Thin abstraction over the native NFC session so the race-sensitive
/// lifecycle logic in [NfcService] can be exercised in tests without
/// touching `nfc_manager` or a real tag. Tests override
/// [NfcService.debugDriverOverride] to inject a fake.
abstract class NfcSessionDriver {
  Future<bool> isAvailable();

  /// Start a native NFC session. [onDiscovered] is called once per delivered
  /// discovery event with a lazy UID extractor — callers only pay the
  /// extraction cost if they actually intend to process the tag.
  Future<void> startSession({
    required Future<void> Function(String? Function() extractUid) onDiscovered,
    void Function(Object error)? onError,
  });

  Future<void> stopSession();
}

class _DefaultNfcSessionDriver implements NfcSessionDriver {
  const _DefaultNfcSessionDriver();

  @override
  Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  @override
  Future<void> startSession({
    required Future<void> Function(String? Function() extractUid) onDiscovered,
    void Function(Object error)? onError,
  }) {
    return NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        String? cached;
        bool cachedSet = false;
        String? extractor() {
          if (!cachedSet) {
            cached = NfcService.extractUid(tag);
            cachedSet = true;
          }
          return cached;
        }

        await onDiscovered(extractor);
      },
      onError: onError == null
          ? null
          : (error) async {
              onError(error);
            },
    );
  }

  @override
  Future<void> stopSession() => NfcManager.instance.stopSession();
}

/// Universal NFC service that reads the hardware UID from ANY card type.
///
/// Supported card types:
/// - e-KTP (NfcA / ISO 14443-A)
/// - e-Toll, building access cards (MifareClassic)
/// - Flazz BCA (NfcF / FeliCa)
/// - Bank cards, smart cards (IsoDep / ISO 14443-4)
/// - Mifare Ultralight, event tickets (MifareUltralight)
/// - Any NDEF-formatted card (Ndef)
/// - ISO 14443-B cards (NfcB)
/// - ISO 15693 cards (NfcV)
class NfcService {
  static bool _isAvailable = false;

  static const NfcSessionDriver _defaultDriver = _DefaultNfcSessionDriver();

  /// Test-only hook. Production code must leave this null.
  static NfcSessionDriver? debugDriverOverride;

  static NfcSessionDriver get _driver =>
      debugDriverOverride ?? _defaultDriver;

  /// Serializes start/stop calls so that a cleanup fired by one listener
  /// never overlaps with a subsequent start. Prevents the native platform
  /// exception that causes a force-close when "Scan Ulang" / "Coba Lagi"
  /// is tapped in quick succession.
  static Future<void> _pendingOp = Future<void>.value();

  static Future<void> _enqueue(Future<void> Function() task) {
    final chained =
        _pendingOp.catchError((Object _) {}).then((_) => task());
    _pendingOp = chained.catchError((Object _) {});
    return chained;
  }

  /// Initialize NFC hardware. Returns true if NFC is supported and enabled.
  static Future<bool> init() async {
    try {
      _isAvailable = await _driver.isAvailable();
      return _isAvailable;
    } catch (_) {
      return false;
    }
  }

  static bool get isAvailable => _isAvailable;

  /// ─────────────────────────────────────────────────────────────────
  /// UNIVERSAL UID EXTRACTOR
  /// Tries every known NFC technology in priority order.
  /// Priority: NfcA (most common in ID) → NfcB → IsoDep → MifareClassic
  ///           → MifareUltralight → NfcF → NfcV → Ndef (fallback)
  /// ─────────────────────────────────────────────────────────────────
  static String? extractUid(NfcTag tag) {
    Uint8List? bytes;

    // 1. NfcA (ISO 14443-A) — e-KTP, e-Money, most Indonesian ID cards
    final nfcA = NfcA.from(tag);
    if (nfcA?.identifier != null && nfcA!.identifier.isNotEmpty) {
      bytes = nfcA.identifier;
    }

    // 2. NfcB (ISO 14443-B) — some bank cards, biometric passports
    if (bytes == null) {
      final nfcB = NfcB.from(tag);
      if (nfcB?.identifier != null && nfcB!.identifier.isNotEmpty) {
        bytes = nfcB.identifier;
      }
    }

    // 3. IsoDep (ISO 14443-4) — smart cards, EMV bank cards
    if (bytes == null) {
      final isoDep = IsoDep.from(tag);
      if (isoDep?.identifier != null && isoDep!.identifier.isNotEmpty) {
        bytes = isoDep.identifier;
      }
    }

    // 4. MifareClassic — e-Toll Mandiri, older building access cards
    if (bytes == null) {
      final mifare = MifareClassic.from(tag);
      if (mifare?.identifier != null && mifare!.identifier.isNotEmpty) {
        bytes = mifare.identifier;
      }
    }

    // 5. MifareUltralight — cheap event tickets, some loyalty cards
    if (bytes == null) {
      final ultralight = MifareUltralight.from(tag);
      if (ultralight?.identifier != null &&
          ultralight!.identifier.isNotEmpty) {
        bytes = ultralight.identifier;
      }
    }

    // 6. NfcF (FeliCa/JIS 6319-4) — Flazz BCA, some transit cards
    if (bytes == null) {
      final nfcF = NfcF.from(tag);
      if (nfcF?.identifier != null && nfcF!.identifier.isNotEmpty) {
        bytes = nfcF.identifier;
      }
    }

    // 7. NfcV (ISO 15693) — some HF access cards
    if (bytes == null) {
      final nfcV = NfcV.from(tag);
      if (nfcV?.identifier != null && nfcV!.identifier.isNotEmpty) {
        bytes = nfcV.identifier;
      }
    }

    // 8. Ndef — fallback for NDEF-formatted tags
    if (bytes == null) {
      final ndef = Ndef.from(tag);
      if (ndef?.additionalData['identifier'] is Uint8List) {
        final id = ndef!.additionalData['identifier'] as Uint8List;
        if (id.isNotEmpty) bytes = id;
      }
    }

    if (bytes == null || bytes.isEmpty) return null;
    return _formatUid(bytes);
  }

  /// Starts a single persistent NFC session for the kiosk idle screen.
  ///
  /// Uses ONE startSession() call that stays active — onDiscovered fires
  /// every time a card is presented. A [processing] flag prevents double
  /// processing when Android delivers multiple discovery events for one tap.
  ///
  /// Returns an awaitable cancel callback — callers MUST await it before
  /// starting another session to avoid overlapping native start/stop calls.
  static Future<void> Function() startListener(
    void Function(String uid) onTag,
    void Function(Object err)? onError,
  ) {
    bool active = true;
    bool processing = false;
    DateTime? lastErrorTime;

    _enqueue(() async {
      if (!active) return;
      await _driver.startSession(
        onDiscovered: (String? Function() extract) async {
          if (!active || processing) return;
          processing = true;
          try {
            final uid = extract();
            if (uid != null && uid.isNotEmpty) {
              if (active) onTag(uid);
            } else {
              throw Exception('Tipe kartu NFC tidak didukung');
            }
          } catch (e) {
            if (active) {
              final now = DateTime.now();
              if (lastErrorTime == null ||
                  now.difference(lastErrorTime!).inSeconds > 2) {
                lastErrorTime = now;
                onError?.call(e);
              }
            }
          } finally {
            await Future<void>.delayed(
              Duration(milliseconds: AppConstants.nfcDebounceMs),
            );
            processing = false;
          }
        },
        onError: (error) {
          if (!active) return;
          final now = DateTime.now();
          if (lastErrorTime == null ||
              now.difference(lastErrorTime!).inSeconds > 2) {
            lastErrorTime = now;
            onError?.call(error);
          }
        },
      );
    }).catchError((Object e) {
      if (active) onError?.call(e);
    });

    return () async {
      active = false;
      await _enqueue(() async {
        try {
          await _driver.stopSession();
        } catch (_) {}
      });
    };
  }

  /// Starts a one-shot NFC session for employee card registration.
  ///
  /// The first supported card stops the session before notifying the UI.
  /// Duplicate discovery events from the same tap are ignored. On any
  /// error (unsupported card, platform exception) the session is torn
  /// down so the caller can cleanly restart with a fresh session.
  static Future<void> Function() startRegistrationListener(
    void Function(String uid) onTag,
    void Function(Object err)? onError,
  ) {
    bool active = true;
    bool claimed = false; // first supported tap wins
    bool terminated = false; // exactly one stop through the queue

    Future<void> drainStop() {
      if (terminated) return Future<void>.value();
      terminated = true;
      return _enqueue(() async {
        try {
          await _driver.stopSession();
        } catch (_) {}
      });
    }

    _enqueue(() async {
      if (!active) return;
      await _driver.startSession(
        onDiscovered: (String? Function() extract) async {
          if (!active || claimed) return;
          claimed = true;
          String? uid;
          Object? failure;
          try {
            uid = extract();
            if (uid == null || uid.isEmpty) {
              failure = Exception('Tipe kartu NFC tidak didukung');
            }
          } catch (e) {
            failure = e;
          }
          await drainStop();
          if (!active) return;
          if (failure != null) {
            claimed = false; // allow the next session (after restart) to succeed
            onError?.call(failure);
            return;
          }
          onTag(uid!);
        },
        onError: (error) async {
          if (!active || claimed) return;
          claimed = true;
          await drainStop();
          if (!active) return;
          claimed = false;
          onError?.call(error);
        },
      );
    }).catchError((Object e) {
      if (!active) return;
      onError?.call(e);
    });

    return () async {
      active = false;
      await drainStop();
    };
  }

  /// Convert a byte array to colon-separated uppercase hex: "04:AB:CD:EF"
  static String _formatUid(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}

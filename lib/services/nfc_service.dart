import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

import '../core/constants.dart';

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

  /// Initialize NFC hardware. Returns true if NFC is supported and enabled.
  static Future<bool> init() async {
    try {
      _isAvailable = await NfcManager.instance.isAvailable();
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
      if (ultralight?.identifier != null && ultralight!.identifier.isNotEmpty) {
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
  /// every time a card is presented. A [_processing] flag prevents double
  /// processing when Android delivers multiple discovery events for one tap.
  ///
  /// Returns a cancel callback — call it to stop listening.
  static Future<void> Function() startListener(
    void Function(String uid) onTag,
    void Function(Object err)? onError,
  ) {
    bool active = true;
    bool processing = false; // anti-double-scan guard
    DateTime? lastErrorTime;

    NfcManager.instance
        .startSession(
      onDiscovered: (NfcTag tag) async {
        // Ignore if already processing a tag or listener was stopped
        if (!active || processing) return;
        processing = true;
        try {
          final uid = extractUid(tag);
          if (uid != null && uid.isNotEmpty) {
            onTag(uid);
          } else {
            throw Exception('Tipe kartu NFC tidak didukung');
          }
        } catch (e, stack) {
          // ignore: avoid_print
          print('[NfcService] Error processing tag: $e\n$stack');
          if (active) {
            final now = DateTime.now();
            if (lastErrorTime == null || now.difference(lastErrorTime!).inSeconds > 2) {
              lastErrorTime = now;
              onError?.call(e);
            }
          }
        } finally {
          // Debounce: wait before accepting next scan
          await Future<void>.delayed(
            Duration(milliseconds: AppConstants.nfcDebounceMs),
          );
          processing = false;
        }
      },
      onError: (error) async {
        // ignore: avoid_print
        print('[NfcService] session error: $error');
        if (active) {
          final now = DateTime.now();
          if (lastErrorTime == null || now.difference(lastErrorTime!).inSeconds > 2) {
            lastErrorTime = now;
            onError?.call(error);
          }
        }
      },
    )
        .catchError((Object e) {
      if (active) onError?.call(e);
    });

    // Return cancel function
    return () async {
      active = false;
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
    };
  }

  /// Starts a one-shot NFC session for employee card registration.
  ///
  /// The first supported card stops the session before notifying the UI.
  /// Duplicate discovery events from the same tap are ignored.
  static Future<void> Function() startRegistrationListener(
    void Function(String uid) onTag,
    void Function(Object err)? onError,
  ) {
    bool active = true;
    bool registered = false;

    NfcManager.instance
        .startSession(
      onDiscovered: (NfcTag tag) async {
        if (!active || registered) return;
        registered = true;
        try {
          final uid = extractUid(tag);
          if (uid != null && uid.isNotEmpty) {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
            if (active) onTag(uid);
          } else {
            registered = false;
            throw Exception('Tipe kartu NFC tidak didukung');
          }
        } catch (e) {
          if (active && !registered) {
            onError?.call(e);
          }
        }
      },
      onError: (error) async {
        if (active) onError?.call(error);
      },
    )
        .catchError((Object e) {
      if (active) onError?.call(e);
    });

    return () async {
      active = false;
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
    };
  }

  /// Convert a byte array to colon-separated uppercase hex: "04:AB:CD:EF"
  static String _formatUid(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}

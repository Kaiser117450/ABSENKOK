// lib/widgets/face_capture_state_machine.dart
//
// Pure state machine for the bank-style capture flow. No camera, no
// UI, no async — easy to unit test deterministically.

import '../core/constants.dart';
import '../services/face_detection_service.dart';

enum CaptureState { searching, aligning, promptBlink, capturing, retry, exhausted, done }

class FaceCaptureStateMachine {
  CaptureState _state = CaptureState.searching;
  DateTime? _alignedSince;
  DateTime? _blinkPromptStart;
  bool _sawClosedEyes = false;
  int _attempts = 0;

  CaptureState get state => _state;
  int get attempts => _attempts;

  /// Drives one tick of the FSM from a fresh detection plus current time.
  /// Returns the new state.
  CaptureState onDetection(FaceDetectionResult r, DateTime now) {
    switch (_state) {
      case CaptureState.searching:
        if (r.alignment == FaceAlignment.aligned) {
          _state = CaptureState.aligning;
          _alignedSince = now;
        }
        break;

      case CaptureState.aligning:
        if (r.alignment != FaceAlignment.aligned) {
          _state = CaptureState.searching;
          _alignedSince = null;
        } else if (_alignedSince != null &&
            now.difference(_alignedSince!).inMilliseconds >=
                AppConstants.attendancePhotoStableFaceMs) {
          _state = CaptureState.promptBlink;
          _blinkPromptStart = now;
          _sawClosedEyes = false;
        }
        break;

      case CaptureState.promptBlink:
        if (r.alignment != FaceAlignment.aligned) {
          _state = CaptureState.searching;
          _alignedSince = null;
          _blinkPromptStart = null;
          _sawClosedEyes = false;
          break;
        }
        if (r.bothEyesClosed) {
          _sawClosedEyes = true;
        } else if (_sawClosedEyes && r.bothEyesOpen) {
          _state = CaptureState.capturing;
          break;
        }
        if (_blinkPromptStart != null &&
            now.difference(_blinkPromptStart!).inMilliseconds >=
                AppConstants.attendancePhotoBlinkWindowMs) {
          _attempts += 1;
          if (_attempts >= AppConstants.attendancePhotoMaxBlinkAttempts) {
            _state = CaptureState.exhausted;
          } else {
            _state = CaptureState.retry;
          }
        }
        break;

      case CaptureState.retry:
        if (r.alignment == FaceAlignment.aligned) {
          _state = CaptureState.promptBlink;
          _blinkPromptStart = now;
          _sawClosedEyes = false;
        }
        break;

      case CaptureState.capturing:
      case CaptureState.done:
      case CaptureState.exhausted:
        break;
    }
    return _state;
  }

  void markDone() {
    _state = CaptureState.done;
  }

  void reset() {
    _state = CaptureState.searching;
    _alignedSince = null;
    _blinkPromptStart = null;
    _sawClosedEyes = false;
    _attempts = 0;
  }
}

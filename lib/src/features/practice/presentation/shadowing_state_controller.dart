import 'shadowing_state.dart';

class ShadowingStateController {
  ShadowingState _state;

  ShadowingStateController({
    ShadowingState initialState = ShadowingState.idle,
  }) : _state = initialState;

  ShadowingState get state => _state;

  void activateMode() {
    _state = _state.copyWith(
      isMode: true,
      locked: true,
      busy: false,
      recording: false,
      remaining: Duration.zero,
      phase: ShadowingPhase.listening,
    );
  }

  void deactivateMode() {
    _state = _state.copyWith(
      isMode: false,
      locked: false,
      phase: ShadowingPhase.idle,
      remaining: Duration.zero,
    );
  }

  void lockMode() {
    _state = _state.copyWith(locked: true);
  }

  void setRemaining(Duration remaining) {
    _state = _state.copyWith(remaining: remaining);
  }

  void enterRecordingPhase() {
    _state = _state.copyWith(
      busy: true,
      phase: ShadowingPhase.recording,
    );
  }

  void setRecording(bool value) {
    _state = _state.copyWith(recording: value);
  }

  void setPhase(ShadowingPhase phase) {
    _state = _state.copyWith(phase: phase);
  }

  void finalizeStepState() {
    _state = _state.copyWith(
      busy: false,
      recording: false,
      remaining: Duration.zero,
      phase: _state.isMode ? ShadowingPhase.listening : ShadowingPhase.idle,
    );
  }

  void resetStepState({required bool keepMode}) {
    _state = _state.copyWith(
      busy: false,
      recording: false,
      remaining: Duration.zero,
      phase: keepMode && _state.isMode
          ? ShadowingPhase.listening
          : ShadowingPhase.idle,
    );
  }
}

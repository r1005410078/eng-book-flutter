import 'package:engbooks/src/features/practice/presentation/shadowing_state.dart';
import 'package:engbooks/src/features/practice/presentation/shadowing_state_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activateMode initializes shadowing mode defaults', () {
    final controller = ShadowingStateController();

    controller.activateMode();
    final state = controller.state;

    expect(state.isMode, isTrue);
    expect(state.locked, isTrue);
    expect(state.busy, isFalse);
    expect(state.recording, isFalse);
    expect(state.remaining, Duration.zero);
    expect(state.phase, ShadowingPhase.listening);
  });

  test('deactivateMode turns mode off and resets idle fields', () {
    final controller = ShadowingStateController();
    controller.activateMode();

    controller.deactivateMode();
    final state = controller.state;

    expect(state.isMode, isFalse);
    expect(state.locked, isFalse);
    expect(state.remaining, Duration.zero);
    expect(state.phase, ShadowingPhase.idle);
  });

  test('enterRecordingPhase and finalizeStepState transition correctly', () {
    final controller = ShadowingStateController();
    controller.activateMode();

    controller.enterRecordingPhase();
    controller.setRecording(true);
    controller.setRemaining(const Duration(seconds: 2));

    expect(controller.state.busy, isTrue);
    expect(controller.state.recording, isTrue);
    expect(controller.state.phase, ShadowingPhase.recording);
    expect(controller.state.remaining, const Duration(seconds: 2));

    controller.finalizeStepState();
    final state = controller.state;
    expect(state.busy, isFalse);
    expect(state.recording, isFalse);
    expect(state.remaining, Duration.zero);
    expect(state.phase, ShadowingPhase.listening);
  });

  test('resetStepState respects keepMode and mode state', () {
    final controller = ShadowingStateController();
    controller.activateMode();
    controller.enterRecordingPhase();
    controller.setRecording(true);
    controller.setRemaining(const Duration(seconds: 1));

    controller.resetStepState(keepMode: true);
    expect(controller.state.phase, ShadowingPhase.listening);
    expect(controller.state.busy, isFalse);
    expect(controller.state.recording, isFalse);
    expect(controller.state.remaining, Duration.zero);

    controller.deactivateMode();
    controller.resetStepState(keepMode: true);
    expect(controller.state.phase, ShadowingPhase.idle);
  });
}

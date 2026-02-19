import 'package:record/record.dart';

enum SentenceEndAction { loopCurrent, advance }

class SentenceEndDecision {
  final SentenceEndAction action;
  final int nextRemainingLoops;

  const SentenceEndDecision({
    required this.action,
    required this.nextRemainingLoops,
  });
}

SentenceEndDecision decideSentenceEndAction({
  required int remainingLoops,
}) {
  final safeRemaining = remainingLoops < 1 ? 1 : remainingLoops;
  if (safeRemaining > 1) {
    return SentenceEndDecision(
      action: SentenceEndAction.loopCurrent,
      nextRemainingLoops: safeRemaining - 1,
    );
  }
  return const SentenceEndDecision(
    action: SentenceEndAction.advance,
    nextRemainingLoops: 1,
  );
}

enum AutoRecordAvailability {
  available,
  permissionDenied,
  unsupported,
}

abstract class AutoRecordPermissionProbe {
  Future<bool> hasPermission();
}

class AudioRecorderPermissionProbe implements AutoRecordPermissionProbe {
  final AudioRecorder recorder;

  AudioRecorderPermissionProbe(this.recorder);

  @override
  Future<bool> hasPermission() {
    return recorder.hasPermission();
  }
}

Future<AutoRecordAvailability> detectAutoRecordAvailability(
  AutoRecordPermissionProbe probe,
) async {
  try {
    final granted = await probe.hasPermission();
    return granted
        ? AutoRecordAvailability.available
        : AutoRecordAvailability.permissionDenied;
  } catch (_) {
    return AutoRecordAvailability.unsupported;
  }
}

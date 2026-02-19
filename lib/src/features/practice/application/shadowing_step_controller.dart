import 'shadowing_auto_record_service.dart';

class ShadowingStepController {
  final ShadowingAutoRecordService autoRecordService;
  final Duration extraDuration;

  const ShadowingStepController({
    required this.autoRecordService,
    this.extraDuration = const Duration(milliseconds: 120),
  });

  Future<void> runStep({
    required bool autoRecord,
    required bool shouldContinuePlayback,
    required int currentIndex,
    required int sentenceCount,
    required String sentenceId,
    required Duration sentenceDuration,
    required double playbackSpeed,
    required bool Function() isActive,
    required Future<void> Function() pauseCurrentMedia,
    required Future<void> Function() playCurrentMedia,
    required Future<void> Function(int index) seekToSentence,
    required void Function(Duration total) startCountdown,
    required void Function() stopCountdown,
    required Future<void> Function() stopRecordingIfNeeded,
    required void Function() onEnterRecordingPhase,
    required void Function() onRecordingStarted,
    required void Function(String warning) onWarning,
    required void Function() onEnterAdvancingPhase,
    required void Function() onReachedEnd,
    required void Function() onResumePlaybackIntent,
    required void Function() onFinalize,
  }) async {
    final safeDuration = sentenceDuration > Duration.zero
        ? sentenceDuration
        : const Duration(seconds: 1);
    final speed = playbackSpeed <= 0 ? 1.0 : playbackSpeed;
    final alignedToPlayback = Duration(
      milliseconds: (safeDuration.inMilliseconds / speed).round(),
    );
    final recordWindow = alignedToPlayback + extraDuration;

    onEnterRecordingPhase();

    try {
      await pauseCurrentMedia();
      if (!isActive()) return;

      if (autoRecord) {
        final recordResult = await autoRecordService.tryStart(
          sentenceId: sentenceId,
        );
        if (!isActive()) return;
        if (recordResult.started) {
          onRecordingStarted();
        } else if (recordResult.warning != null) {
          onWarning(recordResult.warning!);
        }
      }

      startCountdown(recordWindow);
      await Future.delayed(recordWindow);
      stopCountdown();
      await stopRecordingIfNeeded();

      if (!isActive()) return;
      onEnterAdvancingPhase();

      final nextIndex = currentIndex + 1;
      if (nextIndex >= sentenceCount) {
        onReachedEnd();
        return;
      }

      if (shouldContinuePlayback) {
        onResumePlaybackIntent();
      }

      await seekToSentence(nextIndex);
      if (shouldContinuePlayback) {
        await playCurrentMedia();
      }
    } finally {
      onFinalize();
    }
  }
}

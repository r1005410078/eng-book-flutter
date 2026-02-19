import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class PracticeMediaPlaybackService {
  const PracticeMediaPlaybackService();

  Future<void> pause({
    required bool isAudioMode,
    required AudioPlayer audioPlayer,
    required VideoPlayerController videoController,
  }) async {
    if (isAudioMode) {
      await audioPlayer.pause();
      return;
    }
    if (videoController.value.isInitialized) {
      await videoController.pause();
    }
  }

  Future<void> play({
    required bool isAudioMode,
    required AudioPlayer audioPlayer,
    required VideoPlayerController videoController,
  }) async {
    if (isAudioMode) {
      await audioPlayer.play();
      return;
    }
    if (videoController.value.isInitialized) {
      await videoController.play();
    }
  }

  Future<void> setPlaying({
    required bool shouldPlay,
    required bool isAudioMode,
    required AudioPlayer audioPlayer,
    required VideoPlayerController videoController,
  }) async {
    if (shouldPlay) {
      await play(
        isAudioMode: isAudioMode,
        audioPlayer: audioPlayer,
        videoController: videoController,
      );
      return;
    }
    await pause(
      isAudioMode: isAudioMode,
      audioPlayer: audioPlayer,
      videoController: videoController,
    );
  }

  bool actualPlaying({
    required bool isAudioMode,
    required AudioPlayer audioPlayer,
    required VideoPlayerController videoController,
  }) {
    if (isAudioMode) return audioPlayer.playing;
    return videoController.value.isInitialized &&
        videoController.value.isPlaying;
  }

  Duration activeDuration({
    required bool isAudioMode,
    required Duration audioDuration,
    required VideoPlayerController videoController,
  }) {
    if (isAudioMode) return audioDuration;
    if (!videoController.value.isInitialized) return Duration.zero;
    return videoController.value.duration;
  }

  Duration? durationForProgress({
    required double progress,
    required bool isAudioMode,
    required Duration audioDuration,
    required VideoPlayerController videoController,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    final total = activeDuration(
      isAudioMode: isAudioMode,
      audioDuration: audioDuration,
      videoController: videoController,
    );
    if (total <= Duration.zero) return null;
    return Duration(
      milliseconds: (total.inMilliseconds * clamped).round(),
    );
  }

  Future<void> seekByProgress({
    required double progress,
    required bool isAudioMode,
    required Duration audioDuration,
    required AudioPlayer audioPlayer,
    required VideoPlayerController videoController,
  }) async {
    final target = durationForProgress(
      progress: progress,
      isAudioMode: isAudioMode,
      audioDuration: audioDuration,
      videoController: videoController,
    );
    if (target == null) return;
    if (isAudioMode) {
      await audioPlayer.seek(target);
      return;
    }
    if (videoController.value.isInitialized) {
      await videoController.seekTo(target);
    }
  }
}

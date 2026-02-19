import 'package:engbooks/src/features/practice/application/practice_media_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PracticeMediaPlaybackService', () {
    const service = PracticeMediaPlaybackService();

    test('durationForProgress uses audio duration in audio mode', () {
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/video.mp4'),
      );

      final result = service.durationForProgress(
        progress: 0.25,
        isAudioMode: true,
        audioDuration: const Duration(seconds: 40),
        videoController: videoController,
      );

      expect(result, const Duration(seconds: 10));
    });

    test('durationForProgress returns null when video is not initialized', () {
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/video.mp4'),
      );

      final result = service.durationForProgress(
        progress: 0.5,
        isAudioMode: false,
        audioDuration: Duration.zero,
        videoController: videoController,
      );

      expect(result, isNull);
    });

    test('actualPlaying returns false when video is not initialized', () async {
      final audioPlayer = AudioPlayer();
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/video.mp4'),
      );

      final result = service.actualPlaying(
        isAudioMode: false,
        audioPlayer: audioPlayer,
        videoController: videoController,
      );

      expect(result, isFalse);

      await audioPlayer.dispose();
      await videoController.dispose();
    });

    test('setPlaying in video mode no-ops safely when not initialized',
        () async {
      final audioPlayer = AudioPlayer();
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/video.mp4'),
      );

      await service.setPlaying(
        shouldPlay: true,
        isAudioMode: false,
        audioPlayer: audioPlayer,
        videoController: videoController,
      );
      await service.setPlaying(
        shouldPlay: false,
        isAudioMode: false,
        audioPlayer: audioPlayer,
        videoController: videoController,
      );

      await audioPlayer.dispose();
      await videoController.dispose();
    });
  });
}

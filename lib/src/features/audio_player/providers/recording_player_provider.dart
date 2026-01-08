import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'recording_player_provider.g.dart';

@riverpod
class RecordingPlayerController extends _$RecordingPlayerController {
  late final AudioPlayer _player;

  @override
  bool build() {
    _player = AudioPlayer();

    _player.playerStateStream.listen((playerState) {
      // Update state based on playing status
      state = playerState.playing;
    });

    ref.onDispose(() {
      _player.dispose();
    });
    return false;
  }

  Future<void> play(String path) async {
    try {
      if (_player.playing) {
        await _player.stop();
      }
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      print("RecordingPlayer: Error playing: $e");
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}

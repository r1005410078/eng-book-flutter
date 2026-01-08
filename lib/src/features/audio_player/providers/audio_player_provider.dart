import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:collection/collection.dart';
import '../models/audio_player_state.dart';
import '../models/sentence.dart';
import '../models/mock_data.dart';

part 'audio_player_provider.g.dart';

/// 音频播放器 Provider
///
/// 管理 AudioPlayer 实例和播放状态
@riverpod
class AudioPlayerController extends _$AudioPlayerController {
  late final AudioPlayer _player;

  @override
  AudioPlayerState build() {
    // 初始化播放器
    _player = AudioPlayer();

    // 监听播放状态变化
    _player.playerStateStream.listen((playerState) {
      state = state.copyWith(playerState: playerState);
    });

    // 监听播放进度变化
    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    // 监听时长变化
    _player.durationStream.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    // 确保资源释放
    ref.onDispose(() {
      _player.dispose();
    });

    return AudioPlayerState.initial();
  }

  /// 加载音频文件
  ///
  /// [url] 音频文件 URL（支持本地文件和网络文件）
  Future<void> loadAudio(String url) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _player.setUrl(url);

      state = state.copyWith(
        isLoading: false,
        duration: _player.duration,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载音频失败: ${e.toString()}',
      );
    }
  }

  /// 播放
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      state = state.copyWith(error: '播放失败: ${e.toString()}');
    }
  }

  /// 暂停
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      state = state.copyWith(error: '暂停失败: ${e.toString()}');
    }
  }

  /// 停止（重置到起点）
  Future<void> stop() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (e) {
      state = state.copyWith(error: '停止失败: ${e.toString()}');
    }
  }

  /// 跳转到指定位置
  ///
  /// [position] 目标位置
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      state = state.copyWith(error: '跳转失败: ${e.toString()}');
    }
  }

  /// 设置播放速度
  ///
  /// [speed] 播放速度 (0.5 - 2.0)
  Future<void> setSpeed(double speed) async {
    try {
      // 限制速度范围
      final clampedSpeed = speed.clamp(0.5, 2.0);
      await _player.setSpeed(clampedSpeed);
      state = state.copyWith(speed: clampedSpeed);
    } catch (e) {
      state = state.copyWith(error: '调整速度失败: ${e.toString()}');
    }
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 获取当前播放的句子
  Sentence? get currentSentence {
    final positionMs = state.position.inMilliseconds;
    return MockDataService.sentences.firstWhereOrNull(
      (s) => positionMs >= s.startTimeMs && positionMs < s.endTimeMs,
    );
  }

  /// 获取当前句子索引
  int get currentIndex {
    final sentence = currentSentence;
    if (sentence == null) return -1;
    return MockDataService.sentences.indexOf(sentence);
  }

  /// 播放上一句
  Future<void> previousSentence() async {
    final idx = currentIndex;
    if (idx > 0) {
      final target = MockDataService.sentences[idx - 1];
      await seek(target.start);
    } else {
      await seek(Duration.zero);
    }
  }

  /// 播放下一句
  Future<void> nextSentence() async {
    final idx = currentIndex;
    if (idx != -1 && idx < MockDataService.sentences.length - 1) {
      final target = MockDataService.sentences[idx + 1];
      await seek(target.start);
    }
  }
}

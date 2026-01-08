import 'package:just_audio/just_audio.dart';

/// 音频播放器状态模型
///
/// 封装播放器的完整状态信息
class AudioPlayerState {
  /// 当前播放状态
  final PlayerState playerState;

  /// 当前播放进度
  final Duration position;

  /// 音频总时长
  final Duration? duration;

  /// 播放速度 (0.5x - 2.0x)
  final double speed;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息（如果有）
  final String? error;

  const AudioPlayerState({
    required this.playerState,
    required this.position,
    this.duration,
    this.speed = 1.0,
    this.isLoading = false,
    this.error,
  });

  /// 是否正在播放
  bool get isPlaying => playerState.playing;

  /// 是否已完成
  bool get isCompleted =>
      playerState.processingState == ProcessingState.completed;

  /// 播放进度百分比 (0.0 - 1.0)
  double get progress {
    if (duration == null || duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return position.inMilliseconds / duration!.inMilliseconds;
  }

  /// 创建初始状态
  factory AudioPlayerState.initial() {
    return AudioPlayerState(
      playerState: PlayerState(false, ProcessingState.idle),
      position: Duration.zero,
      duration: null,
      speed: 1.0,
      isLoading: false,
      error: null,
    );
  }

  /// 复制并修改部分字段
  AudioPlayerState copyWith({
    PlayerState? playerState,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isLoading,
    String? error,
  }) {
    return AudioPlayerState(
      playerState: playerState ?? this.playerState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'AudioPlayerState(playing: $isPlaying, position: $position, duration: $duration, speed: ${speed}x)';
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioPlayerControllerHash() =>
    r'4b8149161b91a080e7ad2bffbcf5d20a8533e2a0';

/// 音频播放器 Provider
///
/// 管理 AudioPlayer 实例和播放状态
///
/// Copied from [AudioPlayerController].
@ProviderFor(AudioPlayerController)
final audioPlayerControllerProvider = AutoDisposeNotifierProvider<
    AudioPlayerController, AudioPlayerState>.internal(
  AudioPlayerController.new,
  name: r'audioPlayerControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioPlayerControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AudioPlayerController = AutoDisposeNotifier<AudioPlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

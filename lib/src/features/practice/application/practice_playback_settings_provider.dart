import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/practice_playback_settings_store.dart';

class PracticePlaybackSettingsController
    extends StateNotifier<PracticePlaybackSettings> {
  PracticePlaybackSettingsController()
      : super(PracticePlaybackSettings.defaults) {
    _restore();
  }

  Future<void> _restore() async {
    final restored = await PracticePlaybackSettingsStore.load();
    state = restored;
  }

  Future<void> _set(PracticePlaybackSettings next) async {
    state = next;
    await PracticePlaybackSettingsStore.save(next);
  }

  Future<void> setPlaybackSpeed(double value) async {
    await _set(state.copyWith(playbackSpeed: value.clamp(0.5, 1.0).toDouble()));
  }

  Future<void> setShowEnglish(bool value) async {
    await _set(state.copyWith(showEnglish: value));
  }

  Future<void> setShowChinese(bool value) async {
    await _set(state.copyWith(showChinese: value));
  }

  Future<void> setBlurTranslationByDefault(bool value) async {
    await _set(state.copyWith(blurTranslationByDefault: value));
  }

  Future<void> setCompletionMode(PlaybackCompletionMode mode) async {
    await _set(state.copyWith(completionMode: mode));
  }

  Future<void> setAutoRecord(bool value) async {
    await _set(state.copyWith(autoRecord: value));
  }

  Future<void> setSubtitleScale(double value) async {
    await _set(state.copyWith(subtitleScale: value.clamp(0.0, 1.0).toDouble()));
  }

  Future<void> cycleSubtitleMode() async {
    final s = state;
    if (s.showEnglish && s.showChinese) {
      await _set(s.copyWith(showEnglish: true, showChinese: false));
      return;
    }
    if (s.showEnglish && !s.showChinese) {
      await _set(s.copyWith(showEnglish: false, showChinese: false));
      return;
    }
    await _set(s.copyWith(showEnglish: true, showChinese: true));
  }
}

final practicePlaybackSettingsProvider = StateNotifierProvider<
    PracticePlaybackSettingsController, PracticePlaybackSettings>((ref) {
  return PracticePlaybackSettingsController();
});

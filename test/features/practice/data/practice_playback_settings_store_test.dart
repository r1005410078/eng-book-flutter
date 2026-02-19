import 'package:engbooks/src/features/practice/data/practice_playback_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('store saves and restores playback settings', () async {
    const settings = PracticePlaybackSettings(
      playbackSpeed: 0.75,
      showEnglish: true,
      showChinese: false,
      blurTranslationByDefault: true,
      completionMode: PlaybackCompletionMode.allCoursesLoop,
      autoRecord: true,
      subtitleScale: 0.8,
    );

    await PracticePlaybackSettingsStore.save(settings);
    final loaded = await PracticePlaybackSettingsStore.load();

    expect(loaded.playbackSpeed, 0.75);
    expect(loaded.showEnglish, isTrue);
    expect(loaded.showChinese, isFalse);
    expect(loaded.blurTranslationByDefault, isTrue);
    expect(loaded.completionMode, PlaybackCompletionMode.allCoursesLoop);
    expect(loaded.autoRecord, isTrue);
    expect(loaded.subtitleScale, 0.8);
  });

  test('store returns defaults when data is invalid', () async {
    SharedPreferences.setMockInitialValues({
      'practice_playback_settings_v1': 'not-json',
    });

    final loaded = await PracticePlaybackSettingsStore.load();
    expect(
        loaded.playbackSpeed, PracticePlaybackSettings.defaults.playbackSpeed);
    expect(loaded.showEnglish, PracticePlaybackSettings.defaults.showEnglish);
    expect(loaded.showChinese, PracticePlaybackSettings.defaults.showChinese);
    expect(
      loaded.blurTranslationByDefault,
      PracticePlaybackSettings.defaults.blurTranslationByDefault,
    );
    expect(loaded.completionMode,
        PracticePlaybackSettings.defaults.completionMode);
    expect(loaded.autoRecord, PracticePlaybackSettings.defaults.autoRecord);
    expect(
        loaded.subtitleScale, PracticePlaybackSettings.defaults.subtitleScale);
  });
}

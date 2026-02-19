import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum PlaybackCompletionMode {
  unitLoop,
  courseLoop,
  pauseAfterFinish,
  allCoursesLoop,
}

class PracticePlaybackSettings {
  final double playbackSpeed;
  final bool showEnglish;
  final bool showChinese;
  final bool blurTranslationByDefault;
  final PlaybackCompletionMode completionMode;
  final bool autoRecord;
  final double subtitleScale;

  const PracticePlaybackSettings({
    required this.playbackSpeed,
    required this.showEnglish,
    required this.showChinese,
    required this.blurTranslationByDefault,
    required this.completionMode,
    required this.autoRecord,
    required this.subtitleScale,
  });

  static const defaults = PracticePlaybackSettings(
    playbackSpeed: 1.0,
    showEnglish: true,
    showChinese: true,
    blurTranslationByDefault: false,
    completionMode: PlaybackCompletionMode.courseLoop,
    autoRecord: false,
    subtitleScale: 0.5,
  );

  PracticePlaybackSettings copyWith({
    double? playbackSpeed,
    bool? showEnglish,
    bool? showChinese,
    bool? blurTranslationByDefault,
    PlaybackCompletionMode? completionMode,
    bool? autoRecord,
    double? subtitleScale,
  }) {
    return PracticePlaybackSettings(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      showEnglish: showEnglish ?? this.showEnglish,
      showChinese: showChinese ?? this.showChinese,
      blurTranslationByDefault:
          blurTranslationByDefault ?? this.blurTranslationByDefault,
      completionMode: completionMode ?? this.completionMode,
      autoRecord: autoRecord ?? this.autoRecord,
      subtitleScale: subtitleScale ?? this.subtitleScale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playbackSpeed': playbackSpeed,
      'showEnglish': showEnglish,
      'showChinese': showChinese,
      'blurTranslationByDefault': blurTranslationByDefault,
      'completionMode': completionMode.name,
      'autoRecord': autoRecord,
      'subtitleScale': subtitleScale,
    };
  }

  static PracticePlaybackSettings fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      if (value is String) {
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
      }
      return fallback;
    }

    PlaybackCompletionMode readCompletionMode(
      String key,
      PlaybackCompletionMode fallback,
    ) {
      final value = (json[key] ?? '').toString().trim();
      for (final mode in PlaybackCompletionMode.values) {
        if (mode.name == value) return mode;
      }
      return fallback;
    }

    final speed = readDouble('playbackSpeed', defaults.playbackSpeed)
        .clamp(0.5, 1.0)
        .toDouble();
    final scale =
        readDouble('subtitleScale', defaults.subtitleScale).clamp(0.0, 1.0);

    return PracticePlaybackSettings(
      playbackSpeed: speed,
      showEnglish: readBool('showEnglish', defaults.showEnglish),
      showChinese: readBool('showChinese', defaults.showChinese),
      blurTranslationByDefault: readBool(
        'blurTranslationByDefault',
        defaults.blurTranslationByDefault,
      ),
      completionMode: readCompletionMode(
        'completionMode',
        defaults.completionMode,
      ),
      autoRecord: readBool('autoRecord', defaults.autoRecord),
      subtitleScale: scale,
    );
  }
}

class PracticePlaybackSettingsStore {
  static const _key = 'practice_playback_settings_v1';
  static Future<void> _writeQueue = Future<void>.value();

  static Future<PracticePlaybackSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return PracticePlaybackSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return PracticePlaybackSettings.defaults;
      }
      return PracticePlaybackSettings.fromJson(decoded);
    } catch (_) {
      return PracticePlaybackSettings.defaults;
    }
  }

  static Future<void> save(PracticePlaybackSettings settings) async {
    _writeQueue = _writeQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(settings.toJson()));
    });
    await _writeQueue;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

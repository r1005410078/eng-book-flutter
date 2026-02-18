import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LearningResume {
  final String packageRoot;
  final String courseTitle;
  final String sentenceId;
  final String? lessonId;

  const LearningResume({
    required this.packageRoot,
    required this.courseTitle,
    required this.sentenceId,
    this.lessonId,
  });

  Map<String, dynamic> toJson() {
    return {
      'packageRoot': packageRoot,
      'courseTitle': courseTitle,
      'sentenceId': sentenceId,
      'lessonId': lessonId,
    };
  }

  static LearningResume? fromJson(Map<String, dynamic> json) {
    final packageRoot = (json['packageRoot'] ?? '').toString();
    final courseTitle = (json['courseTitle'] ?? '').toString();
    final sentenceId = (json['sentenceId'] ?? '').toString();
    final lessonId = (json['lessonId'] ?? '').toString();
    if (packageRoot.isEmpty || sentenceId.isEmpty) {
      return null;
    }
    return LearningResume(
      packageRoot: packageRoot,
      courseTitle: courseTitle,
      sentenceId: sentenceId,
      lessonId: lessonId.isEmpty ? null : lessonId,
    );
  }
}

class LearningResumeStore {
  static const _key = 'learning_resume_v1';
  static Future<void> _writeQueue = Future<void>.value();
  static int _latestSaveToken = 0;

  static Future<void> save(LearningResume resume) async {
    final token = ++_latestSaveToken;
    _writeQueue = _writeQueue.then((_) async {
      // Drop stale save requests and keep only the newest one.
      if (token != _latestSaveToken) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(resume.toJson()));
    });
    await _writeQueue;
  }

  static Future<LearningResume?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LearningResume.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

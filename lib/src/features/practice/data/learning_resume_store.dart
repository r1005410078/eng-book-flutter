import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LearningResume {
  final String packageRoot;
  final String courseTitle;
  final String sentenceId;

  const LearningResume({
    required this.packageRoot,
    required this.courseTitle,
    required this.sentenceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'packageRoot': packageRoot,
      'courseTitle': courseTitle,
      'sentenceId': sentenceId,
    };
  }

  static LearningResume? fromJson(Map<String, dynamic> json) {
    final packageRoot = (json['packageRoot'] ?? '').toString();
    final courseTitle = (json['courseTitle'] ?? '').toString();
    final sentenceId = (json['sentenceId'] ?? '').toString();
    if (packageRoot.isEmpty || sentenceId.isEmpty) {
      return null;
    }
    return LearningResume(
      packageRoot: packageRoot,
      courseTitle: courseTitle,
      sentenceId: sentenceId,
    );
  }
}

class LearningResumeStore {
  static const _key = 'learning_resume_v1';

  static Future<void> save(LearningResume resume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(resume.toJson()));
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
}

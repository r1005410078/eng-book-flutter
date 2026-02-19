import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum PracticeStatus { notStarted, inProgress, completed }

class UnitPracticeMetricsView {
  final int practiceCount;
  final double progressPercent;
  final int proficiency;
  final PracticeStatus status;

  const UnitPracticeMetricsView({
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
    required this.status,
  });
}

class CoursePracticeMetricsView {
  final int practiceCount;
  final double progressPercent;
  final int proficiency;

  const CoursePracticeMetricsView({
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
  });
}

class LearningMetricsSnapshot {
  final Map<String, _CourseMetricsRecord> _courses;

  const LearningMetricsSnapshot._(this._courses);

  factory LearningMetricsSnapshot.empty() =>
      const LearningMetricsSnapshot._({});

  factory LearningMetricsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];
    if (rawCourses is! Map) return LearningMetricsSnapshot.empty();
    final courses = <String, _CourseMetricsRecord>{};
    rawCourses.forEach((key, value) {
      if (key is! String || value is! Map<String, dynamic>) return;
      courses[key] = _CourseMetricsRecord.fromJson(value);
    });
    return LearningMetricsSnapshot._(courses);
  }

  Map<String, dynamic> toJson() {
    return {
      'courses': _courses.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  CoursePracticeMetricsView courseView(
    String packageRoot, {
    required int totalSentenceCount,
  }) {
    final course = _courses[packageRoot];
    if (course == null) {
      return const CoursePracticeMetricsView(
        practiceCount: 0,
        progressPercent: 0,
        proficiency: 0,
      );
    }
    final resolvedTotal = _resolvedTotal(
      storedTotal: course.totalSentenceCount,
      fallbackTotal: totalSentenceCount,
    );
    final progress = _progressPercent(
      practicedCount: course.practicedSentenceIds.length,
      totalCount: resolvedTotal,
    );
    return CoursePracticeMetricsView(
      practiceCount: course.practiceCount,
      progressPercent: progress,
      proficiency: _calcProficiency(
        progressPercent: progress,
        practiceCount: course.practiceCount,
      ),
    );
  }

  UnitPracticeMetricsView unitView(
    String packageRoot,
    String lessonKey, {
    required int totalSentenceCount,
  }) {
    final course = _courses[packageRoot];
    final unit = course?.units[lessonKey];
    if (unit == null) {
      return const UnitPracticeMetricsView(
        practiceCount: 0,
        progressPercent: 0,
        proficiency: 0,
        status: PracticeStatus.notStarted,
      );
    }
    final resolvedTotal = _resolvedTotal(
      storedTotal: unit.totalSentenceCount,
      fallbackTotal: totalSentenceCount,
    );
    final progress = _progressPercent(
      practicedCount: unit.practicedSentenceIds.length,
      totalCount: resolvedTotal,
    );
    final status = progress >= 99.9
        ? PracticeStatus.completed
        : (unit.practiceCount > 0 || progress > 0
            ? PracticeStatus.inProgress
            : PracticeStatus.notStarted);
    return UnitPracticeMetricsView(
      practiceCount: unit.practiceCount,
      progressPercent: progress,
      proficiency: _calcProficiency(
        progressPercent: progress,
        practiceCount: unit.practiceCount,
      ),
      status: status,
    );
  }

  static int _resolvedTotal({
    required int storedTotal,
    required int fallbackTotal,
  }) {
    if (storedTotal > 0) return storedTotal;
    if (fallbackTotal > 0) return fallbackTotal;
    return 1;
  }

  static double _progressPercent({
    required int practicedCount,
    required int totalCount,
  }) {
    if (totalCount <= 0) return 0;
    final ratio = practicedCount / totalCount;
    return (ratio * 100).clamp(0, 100).toDouble();
  }

  static int _calcProficiency({
    required double progressPercent,
    required int practiceCount,
  }) {
    final repetitionScore = (practiceCount * 20).clamp(0, 100).toDouble();
    final raw = (progressPercent * 0.7) + (repetitionScore * 0.3);
    return raw.round().clamp(0, 100);
  }
}

class LearningMetricsStore {
  static const _key = 'learning_metrics_v1';
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> recordLessonEntry({
    required String packageRoot,
    required String lessonKey,
    required int totalCourseSentences,
    required int totalLessonSentences,
  }) async {
    if (packageRoot.trim().isEmpty || lessonKey.trim().isEmpty) return;
    _writeQueue = _writeQueue.then((_) async {
      final snapshot = await loadSnapshot();
      final next = Map<String, _CourseMetricsRecord>.from(snapshot._courses);
      final course = next[packageRoot] ?? _CourseMetricsRecord.empty();
      final units = Map<String, _UnitMetricsRecord>.from(course.units);
      final unit = units[lessonKey] ?? _UnitMetricsRecord.empty();
      units[lessonKey] = unit.copyWith(
        practiceCount: unit.practiceCount + 1,
        totalSentenceCount: _maxPositive(
          unit.totalSentenceCount,
          totalLessonSentences,
        ),
      );
      next[packageRoot] = course.copyWith(
        practiceCount: course.practiceCount + 1,
        totalSentenceCount: _maxPositive(
          course.totalSentenceCount,
          totalCourseSentences,
        ),
        units: units,
      );
      await _saveSnapshot(LearningMetricsSnapshot._(next));
    });
    await _writeQueue;
  }

  static Future<void> recordSentencePractice({
    required String packageRoot,
    required String lessonKey,
    required String sentenceId,
    required int totalCourseSentences,
    required int totalLessonSentences,
  }) async {
    if (packageRoot.trim().isEmpty ||
        lessonKey.trim().isEmpty ||
        sentenceId.trim().isEmpty) {
      return;
    }
    _writeQueue = _writeQueue.then((_) async {
      final snapshot = await loadSnapshot();
      final next = Map<String, _CourseMetricsRecord>.from(snapshot._courses);
      final course = next[packageRoot] ?? _CourseMetricsRecord.empty();
      final units = Map<String, _UnitMetricsRecord>.from(course.units);
      final unit = units[lessonKey] ?? _UnitMetricsRecord.empty();
      final nextCourseSentences = Set<String>.from(course.practicedSentenceIds)
        ..add(sentenceId);
      final nextUnitSentences = Set<String>.from(unit.practicedSentenceIds)
        ..add(sentenceId);
      units[lessonKey] = unit.copyWith(
        practicedSentenceIds: nextUnitSentences,
        totalSentenceCount: _maxPositive(
          unit.totalSentenceCount,
          totalLessonSentences,
        ),
      );
      next[packageRoot] = course.copyWith(
        practicedSentenceIds: nextCourseSentences,
        totalSentenceCount: _maxPositive(
          course.totalSentenceCount,
          totalCourseSentences,
        ),
        units: units,
      );
      await _saveSnapshot(LearningMetricsSnapshot._(next));
    });
    await _writeQueue;
  }

  static Future<LearningMetricsSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return LearningMetricsSnapshot.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return LearningMetricsSnapshot.empty();
      }
      return LearningMetricsSnapshot.fromJson(decoded);
    } catch (_) {
      return LearningMetricsSnapshot.empty();
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _saveSnapshot(LearningMetricsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  static int _maxPositive(int a, int b) {
    if (a <= 0) return b > 0 ? b : 0;
    if (b <= 0) return a;
    return a > b ? a : b;
  }
}

class _CourseMetricsRecord {
  final int practiceCount;
  final int totalSentenceCount;
  final Set<String> practicedSentenceIds;
  final Map<String, _UnitMetricsRecord> units;

  const _CourseMetricsRecord({
    required this.practiceCount,
    required this.totalSentenceCount,
    required this.practicedSentenceIds,
    required this.units,
  });

  factory _CourseMetricsRecord.empty() => const _CourseMetricsRecord(
        practiceCount: 0,
        totalSentenceCount: 0,
        practicedSentenceIds: {},
        units: {},
      );

  factory _CourseMetricsRecord.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    final units = <String, _UnitMetricsRecord>{};
    if (rawUnits is Map) {
      rawUnits.forEach((key, value) {
        if (key is! String || value is! Map<String, dynamic>) return;
        units[key] = _UnitMetricsRecord.fromJson(value);
      });
    }
    return _CourseMetricsRecord(
      practiceCount: _toInt(json['practiceCount']),
      totalSentenceCount: _toInt(json['totalSentenceCount']),
      practicedSentenceIds: _stringSet(json['practicedSentenceIds']),
      units: units,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'practiceCount': practiceCount,
      'totalSentenceCount': totalSentenceCount,
      'practicedSentenceIds': practicedSentenceIds.toList(),
      'units': units.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  _CourseMetricsRecord copyWith({
    int? practiceCount,
    int? totalSentenceCount,
    Set<String>? practicedSentenceIds,
    Map<String, _UnitMetricsRecord>? units,
  }) {
    return _CourseMetricsRecord(
      practiceCount: practiceCount ?? this.practiceCount,
      totalSentenceCount: totalSentenceCount ?? this.totalSentenceCount,
      practicedSentenceIds: practicedSentenceIds ?? this.practicedSentenceIds,
      units: units ?? this.units,
    );
  }
}

class _UnitMetricsRecord {
  final int practiceCount;
  final int totalSentenceCount;
  final Set<String> practicedSentenceIds;

  const _UnitMetricsRecord({
    required this.practiceCount,
    required this.totalSentenceCount,
    required this.practicedSentenceIds,
  });

  factory _UnitMetricsRecord.empty() => const _UnitMetricsRecord(
        practiceCount: 0,
        totalSentenceCount: 0,
        practicedSentenceIds: {},
      );

  factory _UnitMetricsRecord.fromJson(Map<String, dynamic> json) {
    return _UnitMetricsRecord(
      practiceCount: _toInt(json['practiceCount']),
      totalSentenceCount: _toInt(json['totalSentenceCount']),
      practicedSentenceIds: _stringSet(json['practicedSentenceIds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'practiceCount': practiceCount,
      'totalSentenceCount': totalSentenceCount,
      'practicedSentenceIds': practicedSentenceIds.toList(),
    };
  }

  _UnitMetricsRecord copyWith({
    int? practiceCount,
    int? totalSentenceCount,
    Set<String>? practicedSentenceIds,
  }) {
    return _UnitMetricsRecord(
      practiceCount: practiceCount ?? this.practiceCount,
      totalSentenceCount: totalSentenceCount ?? this.totalSentenceCount,
      practicedSentenceIds: practicedSentenceIds ?? this.practicedSentenceIds,
    );
  }
}

Set<String> _stringSet(dynamic raw) {
  if (raw is! List) return <String>{};
  return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

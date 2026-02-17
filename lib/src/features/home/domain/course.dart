enum CourseType { video, audio, book }

class Course {
  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final int progress; // 0-100
  final bool isContinue; // "继续学习" tag
  final CourseType type;
  final String? packageRoot;
  final String? firstSentenceId;

  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.progress = 0,
    this.isContinue = false,
    required this.type,
    this.packageRoot,
    this.firstSentenceId,
  });
}

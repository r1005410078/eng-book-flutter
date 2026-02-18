import 'package:flutter/material.dart';

import '../../practice/data/learning_resume_store.dart';
import '../../practice/data/local_course_package_loader.dart';
import '../../practice/presentation/sentence_practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _sentenceId;
  String? _packageRoot;
  String? _courseTitle;

  @override
  void initState() {
    super.initState();
    _prepareEntry();
  }

  Future<void> _prepareEntry() async {
    final resume = await LearningResumeStore.load();
    final localCourses = await listLocalCoursePackages();

    if (!mounted) return;

    if (resume != null) {
      if (resume.packageRoot == LearningResumeStore.mockPackageRoot) {
        setState(() {
          _sentenceId = resume.sentenceId;
          _packageRoot = null;
          _courseTitle = resume.courseTitle;
        });
        return;
      }
      final sentenceExists = await sentenceExistsInLocalPackage(
        packageRoot: resume.packageRoot,
        sentenceId: resume.sentenceId,
      );
      if (!mounted) return;
      if (sentenceExists) {
        setState(() {
          _sentenceId = resume.sentenceId;
          _packageRoot = resume.packageRoot;
          _courseTitle = resume.courseTitle;
        });
        return;
      }
    }

    if (resume != null && localCourses.isNotEmpty) {
      // Resume exists but is invalid; fallback to first available local course.
      setState(() {
        _sentenceId = localCourses.first.firstSentenceId;
        _packageRoot = localCourses.first.packageRoot;
        _courseTitle = localCourses.first.title;
      });
      return;
    }

    if (localCourses.isNotEmpty) {
      final first = localCourses.first;
      setState(() {
        _sentenceId = first.firstSentenceId;
        _packageRoot = first.packageRoot;
        _courseTitle = first.title;
      });
      return;
    }

    setState(() {
      _sentenceId = '1';
      _packageRoot = null;
      _courseTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentenceId = _sentenceId;
    if (sentenceId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 首页即小视频学习页。
    return SentencePracticeScreen(
      sentenceId: sentenceId,
      packageRoot: _packageRoot,
      courseTitle: _courseTitle,
    );
  }
}

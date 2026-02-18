import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../practice/data/course_library_revision.dart';
import '../../practice/data/learning_resume_store.dart';
import '../../practice/data/local_course_package_loader.dart';
import '../../practice/presentation/sentence_practice_screen.dart';
import '../../../routing/routes.dart';
import 'home_empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _sentenceId;
  String? _packageRoot;
  String? _courseTitle;
  bool _showEmptyState = false;

  @override
  void initState() {
    super.initState();
    courseLibraryRevision.addListener(_onCourseLibraryChanged);
    _prepareEntry();
  }

  @override
  void dispose() {
    courseLibraryRevision.removeListener(_onCourseLibraryChanged);
    super.dispose();
  }

  void _onCourseLibraryChanged() {
    _prepareEntry();
  }

  Future<void> _prepareEntry() async {
    final resume = await LearningResumeStore.load();
    final localCourses = await listLocalCoursePackages();
    final usableCourses = localCourses
        .where((c) => _isDownloadCenterTask(c.packageRoot))
        .toList();

    if (!mounted) return;

    if (resume != null && _isDownloadCenterTask(resume.packageRoot)) {
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
          _showEmptyState = false;
        });
        return;
      }
    }

    if (usableCourses.isNotEmpty) {
      final first = usableCourses.first;
      setState(() {
        _sentenceId = first.firstSentenceId;
        _packageRoot = first.packageRoot;
        _courseTitle = first.title;
        _showEmptyState = false;
      });
      return;
    }

    setState(() {
      _sentenceId = null;
      _packageRoot = null;
      _courseTitle = null;
      _showEmptyState = true;
    });
  }

  bool _isDownloadCenterTask(String packageRoot) {
    final normalized = packageRoot.replaceAll('\\', '/');
    if (!normalized.contains('/tasks/')) return false;
    final segments = normalized.split('/');
    final tasksIndex = segments.lastIndexOf('tasks');
    if (tasksIndex < 0 || tasksIndex + 1 >= segments.length) return false;
    final taskId = segments[tasksIndex + 1];
    return taskId.startsWith('task_download_');
  }

  @override
  Widget build(BuildContext context) {
    final sentenceId = _sentenceId;
    if (sentenceId == null && !_showEmptyState) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showEmptyState) {
      return HomeEmptyState(
        onGoToDownloadCenter: () => context.push(Routes.downloadCenter),
      );
    }

    // 首页即小视频学习页。
    return SentencePracticeScreen(
      sentenceId: sentenceId!,
      packageRoot: _packageRoot,
      courseTitle: _courseTitle,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/course_detail_screen.dart';
import '../features/home/domain/course.dart';
import '../features/practice/presentation/playback_settings_screen.dart';
import '../features/practice/presentation/reading_practice_screen.dart';
import '../features/practice/presentation/sentence_practice_screen.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// go_router 路由配置 Provider
@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: Routes.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.home,
        name: 'home',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: Routes.sentencePractice,
        name: 'sentencePractice',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '1';
          final packageRoot = state.uri.queryParameters['package'];
          final courseTitle = state.uri.queryParameters['course'];
          return MaterialPage(
            key: state.pageKey,
            child: SentencePracticeScreen(
              sentenceId: id,
              packageRoot: packageRoot,
              courseTitle: courseTitle,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.playbackSettings,
        name: 'playbackSettings',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const PlaybackSettingsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.readingPractice,
        name: 'readingPractice',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '1';
          final packageRoot = state.uri.queryParameters['package'];
          final courseTitle = state.uri.queryParameters['course'];
          return MaterialPage(
            key: state.pageKey,
            child: ReadingPracticeScreen(
              sentenceId: id,
              packageRoot: packageRoot,
              courseTitle: courseTitle,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.courseDetail,
        name: 'courseDetail',
        pageBuilder: (context, state) {
          final course = state.extra as Course;
          return MaterialPage(
            key: state.pageKey,
            child: CourseDetailScreen(course: course),
          );
        },
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: ErrorScreen(error: state.error),
    ),
  );
}

/// 错误页面
class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('错误'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              error?.toString() ?? '未知错误',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

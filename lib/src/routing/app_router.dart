import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/practice/presentation/sentence_practice_screen.dart';
import '../features/practice/presentation/playback_settings_screen.dart';
import '../features/practice/presentation/reading_practice_screen.dart';
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
          return MaterialPage(
            key: state.pageKey,
            child: SentencePracticeScreen(sentenceId: id),
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
          return MaterialPage(
            key: state.pageKey,
            child: ReadingPracticeScreen(sentenceId: id),
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

/// 临时首页（占位）
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('100LS 英语学习'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headphones, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              '欢迎使用 100LS 英语学习应用',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '开始您的英语学习之旅',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 导航到音频播放器
            ElevatedButton.icon(
              onPressed: () => context.push(Routes.audioPlayer),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('打开音频播放器'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/practice/sentence/1'),
              icon: const Icon(Icons.record_voice_over),
              label: const Text('打开句子练习 (Mock)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

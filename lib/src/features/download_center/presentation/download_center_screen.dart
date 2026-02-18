// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../practice/data/learning_resume_store.dart';
import '../../practice/data/local_course_package_loader.dart';
import '../../../routing/routes.dart';
import '../application/download_center_controller.dart';
import '../data/preset_catalog_loader.dart';
import '../domain/download_models.dart';

class DownloadCenterScreen extends ConsumerWidget {
  const DownloadCenterScreen({super.key});

  String _formatSize(int bytes) {
    if (bytes <= 0) return '--';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _statusText(DownloadTaskSnapshot s) {
    return switch (s.status) {
      DownloadStatus.notDownloaded => '未下载',
      DownloadStatus.downloading => '下载中',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.installing => '安装中',
      DownloadStatus.installed => '已安装',
      DownloadStatus.failed => '失败',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bgColor = Color(0xFF151515);
    const cardColor = Color(0xFF1F1F1F);
    const accent = Color(0xFFFFA726);

    final state = ref.watch(downloadCenterControllerProvider);
    final controller = ref.read(downloadCenterControllerProvider.notifier);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        title: const Text('下载中心'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        data: (data) {
          if (data.catalog.isEmpty) {
            return const Center(
              child: Text(
                '暂无可下载课程目录',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemBuilder: (context, index) {
                final course = data.catalog[index];
                final snapshot = data.snapshotFor(course.id);
                return Dismissible(
                  key: ValueKey('course-${course.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    final confirmed = await _confirmDelete(
                      context,
                      course,
                      snapshot,
                    );
                    if (confirmed == true) {
                      final isCurrentLearning =
                          await _isCurrentLearningCourse(course.id);
                      if (isCurrentLearning) {
                        await LearningResumeStore.clear();
                      }
                      await controller.delete(course.id);
                      if (isCurrentLearning && context.mounted) {
                        context.go(Routes.home);
                      }
                    }
                    // Keep item in list; delete only resets status/artifacts.
                    return false;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: accent.withValues(alpha: 0.2),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ID: ${course.id} · 体积: ${_formatSize(course.sizeBytes)} · v${course.version}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusText(snapshot),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (snapshot.status ==
                                          DownloadStatus.downloading ||
                                      snapshot.status == DownloadStatus.paused)
                                    Text(
                                      '${(snapshot.progress * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              if (snapshot.status ==
                                      DownloadStatus.downloading ||
                                  snapshot.status == DownloadStatus.paused ||
                                  snapshot.status == DownloadStatus.installing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: snapshot.status ==
                                              DownloadStatus.installing
                                          ? null
                                          : snapshot.progress,
                                      minHeight: 6,
                                      backgroundColor: Colors.white10,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              if (snapshot.error != null &&
                                  snapshot.error!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    snapshot.error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          course: course,
                          snapshot: snapshot,
                          onStart: () => controller.startOrResume(course),
                          onPause: () => controller.pause(course.id),
                          onRetry: () => controller.retry(course),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: data.catalog.length,
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    PresetCatalogCourse course,
    DownloadTaskSnapshot snapshot,
  ) async {
    final isCurrentLearning = await _isCurrentLearningCourse(course.id);

    final baseText = switch (snapshot.status) {
      DownloadStatus.installed => '确认删除已安装课程「${course.title}」吗？',
      DownloadStatus.downloading => '确认取消下载并删除临时文件吗？',
      DownloadStatus.paused => '确认删除暂停任务及缓存文件吗？',
      DownloadStatus.failed => '确认删除失败任务及缓存文件吗？',
      DownloadStatus.installing => '当前安装中，确认中断并删除吗？',
      DownloadStatus.notDownloaded => '确认删除该课程的下载状态吗？',
    };
    final text = isCurrentLearning ? '$baseText\n\n删除后会清空当前学习进度。' : baseText;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除课程'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<bool> _isCurrentLearningCourse(String courseId) async {
    final resume = await LearningResumeStore.load();
    if (resume == null) return false;
    final normalized = resume.packageRoot.replaceAll('\\', '/');
    if (normalized.contains('/task_download_$courseId/')) {
      return true;
    }

    final courses = await listLocalCoursePackages();
    for (final c in courses) {
      if (c.packageRoot == resume.packageRoot && c.courseId == courseId) {
        return true;
      }
    }
    return false;
  }
}

class _ActionButton extends StatelessWidget {
  final PresetCatalogCourse course;
  final DownloadTaskSnapshot snapshot;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRetry;

  const _ActionButton({
    required this.course,
    required this.snapshot,
    required this.onStart,
    required this.onPause,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFA726);
    switch (snapshot.status) {
      case DownloadStatus.downloading:
        return FilledButton(
          onPressed: onPause,
          style: FilledButton.styleFrom(backgroundColor: Colors.white24),
          child: const Text('暂停'),
        );
      case DownloadStatus.paused:
        return FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('继续'),
        );
      case DownloadStatus.failed:
        return FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('重试'),
        );
      case DownloadStatus.installing:
        return FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(backgroundColor: Colors.white24),
          child: const Text('安装中'),
        );
      case DownloadStatus.installed:
        return FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(backgroundColor: Colors.white24),
          child: const Text('已安装'),
        );
      case DownloadStatus.notDownloaded:
        return FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('下载'),
        );
    }
  }
}

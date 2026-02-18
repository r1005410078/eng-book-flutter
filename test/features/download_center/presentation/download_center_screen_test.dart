import 'package:engbooks/src/features/download_center/application/download_center_controller.dart';
import 'package:engbooks/src/features/download_center/data/download_center_repository_api.dart';
import 'package:engbooks/src/features/download_center/data/preset_catalog_loader.dart';
import 'package:engbooks/src/features/download_center/domain/download_models.dart';
import 'package:engbooks/src/features/download_center/presentation/download_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DownloadCenterRepository {
  final Map<String, DownloadTaskSnapshot> snapshots;

  _FakeRepo(this.snapshots);

  @override
  Future<void> cancelDownload(String courseId) async {}

  @override
  Future<void> deleteCourseArtifacts(String courseId) async {}

  @override
  Future<bool> isInstalled(String courseId) async => false;

  @override
  Future<Map<String, DownloadTaskSnapshot>> loadSnapshots() async => snapshots;

  @override
  Future<void> pauseDownload(String courseId) async {}

  @override
  Future<void> persistSnapshots(
      Map<String, DownloadTaskSnapshot> snapshots) async {}

  @override
  Future<int?> queryAvailableBytes() async => 1024 * 1024;

  @override
  Future<void> startOrResumeDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {}
}

void main() {
  testWidgets('shows retry button for failed download task', (tester) async {
    const courseId = 'course-a';
    const course = PresetCatalogCourse(
      id: courseId,
      title: 'Course A',
      tags: ['全部'],
      sizeBytes: 100,
      version: '1.0.0',
      url: 'http://example.com/a.zip',
      hash: '',
      cover: null,
    );

    final repo = _FakeRepo({
      courseId: const DownloadTaskSnapshot(
        courseId: courseId,
        status: DownloadStatus.failed,
        downloadedBytes: 30,
        totalBytes: 100,
        error: 'network error',
      ),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadCenterRepositoryProvider.overrideWithValue(repo),
          downloadCenterControllerProvider.overrideWith(
            (ref) => DownloadCenterController(
              ref,
              catalogLoader: () async => [course],
            ),
          ),
        ],
        child: const MaterialApp(home: DownloadCenterScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
  });
}

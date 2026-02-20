import 'package:engbooks/src/features/download_center/application/download_center_controller.dart';
import 'package:engbooks/src/features/download_center/data/download_center_repository_api.dart';
import 'package:engbooks/src/features/download_center/data/preset_catalog_loader.dart';
import 'package:engbooks/src/features/download_center/domain/download_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DownloadCenterRepository {
  Map<String, DownloadTaskSnapshot> snapshots;
  int? availableBytes;
  final Set<String> installed;

  _FakeRepo({
    required this.snapshots,
    required this.availableBytes,
    required this.installed,
  });

  @override
  Future<void> cancelDownload(String courseId) async {}

  @override
  Future<void> deleteCourseArtifacts(String courseId) async {
    snapshots[courseId] = DownloadTaskSnapshot(
      courseId: courseId,
      status: DownloadStatus.notDownloaded,
      downloadedBytes: 0,
      totalBytes: 0,
    );
  }

  @override
  Future<void> clearAllCourseArtifacts() async {
    snapshots = {};
    installed.clear();
  }

  @override
  Future<bool> isInstalled(String courseId) async =>
      installed.contains(courseId);

  @override
  Future<Map<String, DownloadTaskSnapshot>> loadSnapshots() async =>
      Map<String, DownloadTaskSnapshot>.from(snapshots);

  @override
  Future<void> pauseDownload(String courseId) async {}

  @override
  Future<void> persistSnapshots(
      Map<String, DownloadTaskSnapshot> snapshots) async {
    this.snapshots = Map<String, DownloadTaskSnapshot>.from(snapshots);
  }

  @override
  Future<int?> queryAvailableBytes() async => availableBytes;

  @override
  Future<void> startOrResumeDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {
    onProgress(
      snapshot.copyWith(
        status: DownloadStatus.installed,
        downloadedBytes: course.sizeBytes,
        totalBytes: course.sizeBytes,
      ),
    );
  }
}

PresetCatalogCourse _course({String id = 'course-a', int size = 200}) {
  return PresetCatalogCourse(
    id: id,
    title: 'Course $id',
    tags: const ['全部'],
    version: '1.0.0',
    cover: null,
    asset: CourseAsset(
      mode: CourseAssetMode.zip,
      sizeBytes: size,
      sha256: '',
      url: 'http://example.com/$id.zip',
    ),
  );
}

Future<void> _waitForData(ProviderContainer container) async {
  for (var i = 0; i < 20; i++) {
    final s = container.read(downloadCenterControllerProvider);
    if (s.hasValue) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('refresh converts in-progress snapshots to paused on restart', () async {
    final repo = _FakeRepo(
      snapshots: {
        'course-a': const DownloadTaskSnapshot(
          courseId: 'course-a',
          status: DownloadStatus.downloading,
          downloadedBytes: 10,
          totalBytes: 100,
        ),
      },
      availableBytes: 1024 * 1024,
      installed: {},
    );

    final container = ProviderContainer(
      overrides: [
        downloadCenterRepositoryProvider.overrideWithValue(repo),
        downloadCenterControllerProvider.overrideWith(
          (ref) => DownloadCenterController(
            ref,
            catalogLoader: () async => [_course(size: 100)],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitForData(container);
    final state = container.read(downloadCenterControllerProvider).value!;
    expect(state.snapshotFor('course-a').status, DownloadStatus.paused);
  });

  test('startOrResume fails when disk space is insufficient', () async {
    final repo = _FakeRepo(
      snapshots: {},
      availableBytes: 50,
      installed: {},
    );

    final course = _course(size: 500);
    final container = ProviderContainer(
      overrides: [
        downloadCenterRepositoryProvider.overrideWithValue(repo),
        downloadCenterControllerProvider.overrideWith(
          (ref) => DownloadCenterController(
            ref,
            catalogLoader: () async => [course],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitForData(container);
    await container
        .read(downloadCenterControllerProvider.notifier)
        .startOrResume(course);

    final state = container.read(downloadCenterControllerProvider).value!;
    final snapshot = state.snapshotFor(course.id);
    expect(snapshot.status, DownloadStatus.failed);
    expect(snapshot.error, contains('存储空间不足'));
  });

  test('clearAllCaches resets snapshots to notDownloaded', () async {
    final course = _course(id: 'course-a', size: 100);
    final repo = _FakeRepo(
      snapshots: {
        'course-a': const DownloadTaskSnapshot(
          courseId: 'course-a',
          status: DownloadStatus.installed,
          downloadedBytes: 100,
          totalBytes: 100,
        ),
      },
      availableBytes: 1024 * 1024,
      installed: {'course-a'},
    );

    final container = ProviderContainer(
      overrides: [
        downloadCenterRepositoryProvider.overrideWithValue(repo),
        downloadCenterControllerProvider.overrideWith(
          (ref) => DownloadCenterController(
            ref,
            catalogLoader: () async => [course],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitForData(container);
    await container
        .read(downloadCenterControllerProvider.notifier)
        .clearAllCaches();

    final state = container.read(downloadCenterControllerProvider).value!;
    expect(state.snapshotFor('course-a').status, DownloadStatus.notDownloaded);
    expect(repo.installed.contains('course-a'), isFalse);
  });
}

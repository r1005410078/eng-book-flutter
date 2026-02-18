import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/download_center_repository.dart';
import '../data/download_center_repository_api.dart';
import '../data/preset_catalog_loader.dart';
import '../domain/download_models.dart';
import '../../practice/data/course_library_revision.dart';

final downloadCenterRepositoryProvider =
    Provider<DownloadCenterRepository>((ref) {
  return DownloadCenterRepositoryImpl();
});

final downloadCenterControllerProvider = StateNotifierProvider<
    DownloadCenterController, AsyncValue<DownloadCenterState>>(
  (ref) => DownloadCenterController(ref),
);

typedef CatalogLoader = Future<List<PresetCatalogCourse>> Function();

class DownloadCenterState {
  final List<PresetCatalogCourse> catalog;
  final Map<String, DownloadTaskSnapshot> snapshots;

  const DownloadCenterState({
    required this.catalog,
    required this.snapshots,
  });

  DownloadTaskSnapshot snapshotFor(String courseId) {
    return snapshots[courseId] ??
        DownloadTaskSnapshot(
          courseId: courseId,
          status: DownloadStatus.notDownloaded,
          downloadedBytes: 0,
          totalBytes: 0,
        );
  }

  DownloadCenterState copyWith({
    List<PresetCatalogCourse>? catalog,
    Map<String, DownloadTaskSnapshot>? snapshots,
  }) {
    return DownloadCenterState(
      catalog: catalog ?? this.catalog,
      snapshots: snapshots ?? this.snapshots,
    );
  }
}

class DownloadCenterController
    extends StateNotifier<AsyncValue<DownloadCenterState>> {
  final Ref _ref;
  final CatalogLoader _catalogLoader;

  DownloadCenterController(
    this._ref, {
    CatalogLoader? catalogLoader,
  })  : _catalogLoader = catalogLoader ?? loadPresetCatalogCourses,
        super(const AsyncValue.loading()) {
    refresh();
  }

  DownloadCenterRepository get _repo =>
      _ref.read(downloadCenterRepositoryProvider);

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final catalog = await _catalogLoader();
      final snapshots = await _repo.loadSnapshots();

      final normalized = <String, DownloadTaskSnapshot>{};
      for (final c in catalog) {
        final current = snapshots[c.id] ??
            DownloadTaskSnapshot(
              courseId: c.id,
              status: DownloadStatus.notDownloaded,
              downloadedBytes: 0,
              totalBytes: c.sizeBytes,
            );

        var status = current.status;
        if (status == DownloadStatus.downloading ||
            status == DownloadStatus.installing) {
          status = DownloadStatus.paused;
        }

        final installed = await _repo.isInstalled(c.id);
        if (installed) {
          status = DownloadStatus.installed;
        }

        normalized[c.id] = current.copyWith(
          status: status,
          totalBytes: current.totalBytes > 0 ? current.totalBytes : c.sizeBytes,
        );
      }

      await _repo.persistSnapshots(normalized);
      state = AsyncValue.data(
        DownloadCenterState(
          catalog: catalog,
          snapshots: normalized,
        ),
      );
    } catch (e, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> startOrResume(PresetCatalogCourse course) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    var snapshot = currentState.snapshotFor(course.id);
    if (snapshot.status == DownloadStatus.installed ||
        snapshot.status == DownloadStatus.downloading ||
        snapshot.status == DownloadStatus.installing) {
      return;
    }

    snapshot = snapshot.copyWith(
      status: DownloadStatus.downloading,
      totalBytes:
          snapshot.totalBytes > 0 ? snapshot.totalBytes : course.sizeBytes,
      clearError: true,
    );

    final availableBytes = await _repo.queryAvailableBytes();
    final expectedTotal =
        snapshot.totalBytes > 0 ? snapshot.totalBytes : course.sizeBytes;
    final remainingBytes =
        (expectedTotal - snapshot.downloadedBytes).clamp(0, 1 << 62);
    if (availableBytes != null &&
        remainingBytes > 0 &&
        availableBytes < remainingBytes) {
      _updateSnapshot(
        snapshot.copyWith(
          status: DownloadStatus.failed,
          error: '存储空间不足，无法开始下载（剩余 ${_formatBytes(availableBytes)}）。',
        ),
      );
      return;
    }

    _updateSnapshot(snapshot);

    try {
      await _repo.startOrResumeDownload(
        course: course,
        snapshot: snapshot,
        onProgress: _updateSnapshot,
      );
      bumpCourseLibraryRevision();
    } catch (e) {
      _updateSnapshot(
        snapshot.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> pause(String courseId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final snapshot = currentState.snapshotFor(courseId);
    if (snapshot.status != DownloadStatus.downloading) return;

    await _repo.pauseDownload(courseId);
    _updateSnapshot(snapshot.copyWith(status: DownloadStatus.paused));
  }

  Future<void> retry(PresetCatalogCourse course) async {
    await startOrResume(course);
  }

  Future<void> delete(String courseId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    await _repo.deleteCourseArtifacts(courseId);
    bumpCourseLibraryRevision();
    _updateSnapshot(
      DownloadTaskSnapshot(
        courseId: courseId,
        status: DownloadStatus.notDownloaded,
        downloadedBytes: 0,
        totalBytes: 0,
      ),
    );
  }

  void _updateSnapshot(DownloadTaskSnapshot snapshot) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final next = Map<String, DownloadTaskSnapshot>.from(currentState.snapshots);
    next[snapshot.courseId] = snapshot;
    final data = currentState.copyWith(snapshots: next);
    state = AsyncValue.data(data);
    _repo.persistSnapshots(next);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '--';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

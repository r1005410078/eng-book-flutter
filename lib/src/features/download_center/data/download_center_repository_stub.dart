import '../domain/download_models.dart';
import 'download_center_repository_api.dart';
import 'preset_catalog_loader.dart';

class DownloadCenterRepositoryImpl implements DownloadCenterRepository {
  @override
  Future<int?> queryAvailableBytes() async => null;

  @override
  Future<void> cancelDownload(String courseId) async {}

  @override
  Future<void> deleteCourseArtifacts(String courseId) async {}

  @override
  Future<bool> isInstalled(String courseId) async => false;

  @override
  Future<Map<String, DownloadTaskSnapshot>> loadSnapshots() async => {};

  @override
  Future<void> pauseDownload(String courseId) async {}

  @override
  Future<void> persistSnapshots(
      Map<String, DownloadTaskSnapshot> snapshots) async {}

  @override
  Future<void> startOrResumeDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  }) async {
    onProgress(
      snapshot.copyWith(
        status: DownloadStatus.failed,
        error: '当前平台不支持下载中心。',
      ),
    );
  }
}

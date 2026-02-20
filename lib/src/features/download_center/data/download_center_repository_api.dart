import '../domain/download_models.dart';
import 'preset_catalog_loader.dart';

abstract class DownloadCenterRepository {
  Future<int?> queryAvailableBytes();
  Future<Map<String, DownloadTaskSnapshot>> loadSnapshots();
  Future<void> persistSnapshots(Map<String, DownloadTaskSnapshot> snapshots);
  Future<bool> isInstalled(String courseId);
  Future<void> clearAllCourseArtifacts();
  Future<void> startOrResumeDownload({
    required PresetCatalogCourse course,
    required DownloadTaskSnapshot snapshot,
    required void Function(DownloadTaskSnapshot snapshot) onProgress,
  });
  Future<void> pauseDownload(String courseId);
  Future<void> cancelDownload(String courseId);
  Future<void> deleteCourseArtifacts(String courseId);
}

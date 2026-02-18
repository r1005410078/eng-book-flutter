enum DownloadStatus {
  notDownloaded,
  downloading,
  paused,
  installing,
  installed,
  failed,
}

class DownloadTaskSnapshot {
  final String courseId;
  final DownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  const DownloadTaskSnapshot({
    required this.courseId,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.error,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }

  DownloadTaskSnapshot copyWith({
    DownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
    bool clearError = false,
  }) {
    return DownloadTaskSnapshot(
      courseId: courseId,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'status': status.name,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'error': error,
    };
  }

  static DownloadTaskSnapshot fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? '').toString();
    final status = DownloadStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => DownloadStatus.notDownloaded,
    );
    return DownloadTaskSnapshot(
      courseId: (json['courseId'] ?? '').toString(),
      status: status,
      downloadedBytes: _toInt(json['downloadedBytes']),
      totalBytes: _toInt(json['totalBytes']),
      error: (json['error'] ?? '').toString().trim().isEmpty
          ? null
          : (json['error'] ?? '').toString(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

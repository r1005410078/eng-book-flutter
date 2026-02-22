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
  final int currentPartIndex;
  final int currentPartDownloadedBytes;
  final int totalParts;
  final String? error;

  const DownloadTaskSnapshot({
    required this.courseId,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.currentPartIndex = 0,
    this.currentPartDownloadedBytes = 0,
    this.totalParts = 0,
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
    int? currentPartIndex,
    int? currentPartDownloadedBytes,
    int? totalParts,
    String? error,
    bool clearError = false,
  }) {
    return DownloadTaskSnapshot(
      courseId: courseId,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      currentPartIndex: currentPartIndex ?? this.currentPartIndex,
      currentPartDownloadedBytes:
          currentPartDownloadedBytes ?? this.currentPartDownloadedBytes,
      totalParts: totalParts ?? this.totalParts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'status': status.name,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'currentPartIndex': currentPartIndex,
      'currentPartDownloadedBytes': currentPartDownloadedBytes,
      'totalParts': totalParts,
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
      currentPartIndex: _toInt(json['currentPartIndex']),
      currentPartDownloadedBytes: _toInt(json['currentPartDownloadedBytes']),
      totalParts: _toInt(json['totalParts']),
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

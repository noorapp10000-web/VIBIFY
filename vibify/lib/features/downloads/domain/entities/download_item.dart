import 'package:equatable/equatable.dart';

import '../../../player/domain/entities/track.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

class DownloadItem extends Equatable {
  final String id;
  final Track track;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? errorMessage;
  final DateTime createdAt;
  final int? fileSizeBytes;
  final int? downloadedBytes;

  const DownloadItem({
    required this.id,
    required this.track,
    required this.status,
    this.progress = 0.0,
    this.localPath,
    this.errorMessage,
    required this.createdAt,
    this.fileSizeBytes,
    this.downloadedBytes,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isQueued => status == DownloadStatus.queued;

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? errorMessage,
    int? fileSizeBytes,
    int? downloadedBytes,
  }) =>
      DownloadItem(
        id: id,
        track: track,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        localPath: localPath ?? this.localPath,
        errorMessage: errorMessage,
        createdAt: createdAt,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      );

  @override
  List<Object?> get props => [id, track, status, progress, localPath];
}

import '../entities/download_item.dart';
import '../../../player/domain/entities/track.dart';

abstract class DownloadRepository {
  Future<List<DownloadItem>> getAllDownloads();
  Future<DownloadItem> startDownload(Track track);
  Future<void> pauseDownload(String downloadId);
  Future<void> resumeDownload(String downloadId);
  Future<void> cancelDownload(String downloadId);
  Future<void> retryDownload(String downloadId);
  Future<void> deleteDownload(String downloadId);
  Stream<DownloadItem> get downloadProgressStream;
}

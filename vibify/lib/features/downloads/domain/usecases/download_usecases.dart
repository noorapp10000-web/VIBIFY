import '../entities/download_item.dart';
import '../repositories/download_repository.dart';
import '../../../player/domain/entities/track.dart';

class DownloadUsecases {
  final DownloadRepository _repository;

  DownloadUsecases(this._repository);

  Future<List<DownloadItem>> getAll() => _repository.getAllDownloads();
  Future<DownloadItem> start(Track track) => _repository.startDownload(track);
  Future<void> pause(String id) => _repository.pauseDownload(id);
  Future<void> resume(String id) => _repository.resumeDownload(id);
  Future<void> cancel(String id) => _repository.cancelDownload(id);
  Future<void> retry(String id) => _repository.retryDownload(id);
  Future<void> delete(String id) => _repository.deleteDownload(id);
  Stream<DownloadItem> get progressStream => _repository.downloadProgressStream;
}

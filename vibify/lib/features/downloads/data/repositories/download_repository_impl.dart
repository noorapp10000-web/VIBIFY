import '../../../player/domain/entities/track.dart';
import '../../domain/entities/download_item.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/download_datasource.dart';
import '../../../../core/network/network_info.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final DownloadDatasource _datasource;
  final NetworkInfo _networkInfo;

  DownloadRepositoryImpl(this._datasource, this._networkInfo);

  @override
  Future<List<DownloadItem>> getAllDownloads() => _datasource.getAllDownloads();

  @override
  Future<DownloadItem> startDownload(Track track) =>
      _datasource.startDownload(track);

  @override
  Future<void> pauseDownload(String downloadId) =>
      _datasource.pauseDownload(downloadId);

  @override
  Future<void> resumeDownload(String downloadId) =>
      _datasource.resumeDownload(downloadId);

  @override
  Future<void> cancelDownload(String downloadId) =>
      _datasource.cancelDownload(downloadId);

  @override
  Future<void> retryDownload(String downloadId) =>
      _datasource.retryDownload(downloadId);

  @override
  Future<void> deleteDownload(String downloadId) =>
      _datasource.deleteDownload(downloadId);

  @override
  Stream<DownloadItem> get downloadProgressStream =>
      _datasource.downloadProgressStream;
}

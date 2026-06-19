import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/data/datasources/youtube_stream_service.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/download_item.dart';

abstract class DownloadDatasource {
  Future<List<DownloadItem>> getAllDownloads();
  Future<DownloadItem> startDownload(Track track);
  Future<void> pauseDownload(String downloadId);
  Future<void> resumeDownload(String downloadId);
  Future<void> cancelDownload(String downloadId);
  Future<void> retryDownload(String downloadId);
  Future<void> deleteDownload(String downloadId);
  Stream<DownloadItem> get downloadProgressStream;
}

class DownloadDatasourceImpl implements DownloadDatasource {
  final Box _box;
  final YoutubeStreamService _streamService;
  final _uuid = const Uuid();

  final Map<String, bool> _cancelled = {};
  final _progressController = _DownloadProgressController();

  DownloadDatasourceImpl(this._box, this._streamService);

  @override
  Stream<DownloadItem> get downloadProgressStream =>
      _progressController.stream;

  @override
  Future<List<DownloadItem>> getAllDownloads() async {
    final items = <DownloadItem>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        items.add(_fromMap(Map<String, dynamic>.from(data)));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<DownloadItem> startDownload(Track track) async {
    final item = DownloadItem(
      id: _uuid.v4(),
      track: track,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
    );
    await _box.put(item.id, _toMap(item));
    unawaited(_downloadInBackground(item));
    return item;
  }

  Future<void> _downloadInBackground(DownloadItem item) async {
    _cancelled.remove(item.id);
    try {
      var updated = item.copyWith(status: DownloadStatus.downloading);
      await _saveItem(updated);
      _progressController.add(updated);

      if (item.track.source == TrackSource.local ||
          item.track.youtubeVideoId == null) {
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName =
          item.track.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF]'), '_');
      final fileName = '${item.id}_$safeName.m4a';
      final filePath = '${dir.path}/downloads/$fileName';
      await Directory('${dir.path}/downloads').create(recursive: true);

      await _streamService.downloadToFile(
        item.track.youtubeVideoId!,
        filePath,
        onProgress: (received, total) async {
          if (_cancelled[item.id] == true) return;
          // total can be -1 for chunked/streaming responses
          final progress = total > 0 ? received / total : null;
          final current = updated.copyWith(
            status: DownloadStatus.downloading,
            progress: progress ?? updated.progress,
            downloadedBytes: received,
            fileSizeBytes: total > 0 ? total : null,
          );
          await _saveItem(current);
          _progressController.add(current);
          updated = current;
        },
      );

      if (_cancelled[item.id] == true) return;

      final completed = updated.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: filePath,
      );
      await _saveItem(completed);
      _progressController.add(completed);
    } catch (e) {
      if (_cancelled[item.id] == true) return;
      debugPrint('[Download] Error: $e');
      final failed = item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      await _saveItem(failed);
      _progressController.add(failed);
    } finally {
      _cancelled.remove(item.id);
    }
  }

  @override
  Future<void> pauseDownload(String downloadId) async {
    _cancelled[downloadId] = true;
    final item = _getItem(downloadId);
    if (item != null) {
      final paused = item.copyWith(status: DownloadStatus.paused);
      await _saveItem(paused);
      _progressController.add(paused);
    }
  }

  @override
  Future<void> resumeDownload(String downloadId) async {
    final item = _getItem(downloadId);
    if (item != null && item.isPaused) {
      unawaited(_downloadInBackground(item));
    }
  }

  @override
  Future<void> cancelDownload(String downloadId) async {
    _cancelled[downloadId] = true;
    await _box.delete(downloadId);
  }

  @override
  Future<void> retryDownload(String downloadId) async {
    final item = _getItem(downloadId);
    if (item != null && item.isFailed) {
      unawaited(_downloadInBackground(item));
    }
  }

  @override
  Future<void> deleteDownload(String downloadId) async {
    final item = _getItem(downloadId);
    if (item?.localPath != null) {
      final file = File(item!.localPath!);
      if (file.existsSync()) await file.delete();
    }
    await _box.delete(downloadId);
  }

  DownloadItem? _getItem(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return _fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> _saveItem(DownloadItem item) async {
    await _box.put(item.id, _toMap(item));
  }

  Map<String, dynamic> _toMap(DownloadItem item) => {
        'id': item.id,
        'trackId': item.track.id,
        'trackTitle': item.track.title,
        'trackArtist': item.track.artist,
        'trackThumbnailUrl': item.track.thumbnailUrl,
        'trackSource': item.track.source.name,
        'trackYoutubeId': item.track.youtubeVideoId,
        'trackLocalPath': item.track.localPath,
        'status': item.status.name,
        'progress': item.progress,
        'localPath': item.localPath,
        'errorMessage': item.errorMessage,
        'createdAt': item.createdAt.toIso8601String(),
        'fileSizeBytes': item.fileSizeBytes,
        'downloadedBytes': item.downloadedBytes,
      };

  DownloadItem _fromMap(Map<String, dynamic> map) {
    final track = Track(
      id: map['trackId'],
      title: map['trackTitle'],
      artist: map['trackArtist'],
      thumbnailUrl: map['trackThumbnailUrl'],
      source: TrackSource.values.firstWhere(
        (s) => s.name == map['trackSource'],
        orElse: () => TrackSource.youtube,
      ),
      youtubeVideoId: map['trackYoutubeId'],
      localPath: map['trackLocalPath'],
    );
    return DownloadItem(
      id: map['id'],
      track: track,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DownloadStatus.failed,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      localPath: map['localPath'],
      errorMessage: map['errorMessage'],
      createdAt: DateTime.parse(map['createdAt']),
      fileSizeBytes: map['fileSizeBytes'],
      downloadedBytes: map['downloadedBytes'],
    );
  }
}

class _DownloadProgressController {
  final _listeners = <void Function(DownloadItem)>[];
  late final Stream<DownloadItem> stream;

  _DownloadProgressController() {
    stream = Stream.multi((controller) {
      void listener(DownloadItem item) => controller.add(item);
      _listeners.add(listener);
      controller.onCancel = () => _listeners.remove(listener);
    });
  }

  void add(DownloadItem item) {
    for (final listener in _listeners) {
      listener(item);
    }
  }
}

class DownloadException extends AppException {
  const DownloadException({required super.message});
}

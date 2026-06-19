import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeStreamService {
  Future<String?> getAudioUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final audioUrl = streamInfo.url.toString();
      debugPrint('[YoutubeStreamService] ✓ Got audio URL for $videoId');
      return audioUrl;
    } catch (e) {
      debugPrint('[YoutubeStreamService] ✗ getAudioUrl failed for $videoId: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  Future<AudioStreamResult?> getAudioStream(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = manifest.audioOnly.withHighestBitrate();
      final totalBytes = info.size.totalBytes;
      final contentType = 'audio/${info.container.name}';
      final stream = yt.videos.streamsClient.get(info);
      debugPrint(
          '[YoutubeStreamService] ✓ Got audio stream for $videoId ($totalBytes bytes)');
      return AudioStreamResult(
        stream: stream,
        totalBytes: totalBytes,
        contentType: contentType,
        yt: yt,
      );
    } catch (e) {
      debugPrint(
          '[YoutubeStreamService] ✗ getAudioStream failed for $videoId: $e');
      yt.close();
      return null;
    }
  }

  Future<void> downloadToFile(
    String videoId,
    String filePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = manifest.audioOnly.withHighestBitrate();
      final totalBytes = info.size.totalBytes;

      final stream = yt.videos.streamsClient.get(info);
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, totalBytes);
      }
      await sink.flush();
      await sink.close();
      debugPrint(
          '[YoutubeStreamService] ✓ Downloaded $videoId → $filePath');
    } catch (e) {
      debugPrint('[YoutubeStreamService] ✗ downloadToFile failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }
}

class AudioStreamResult {
  final Stream<List<int>> stream;
  final int totalBytes;
  final String contentType;
  final YoutubeExplode yt;

  AudioStreamResult({
    required this.stream,
    required this.totalBytes,
    required this.contentType,
    required this.yt,
  });

  void dispose() => yt.close();
}

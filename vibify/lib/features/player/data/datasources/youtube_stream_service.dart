import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeStreamService {
  /// Returns the best audio URL for [videoId].
  /// Prefers AAC/MP4 for Android compatibility; falls back to any audio stream.
  Future<String?> getAudioUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _pickBestAudio(manifest);
      debugPrint('[YoutubeStreamService] ✓ Got audio URL for $videoId '
          '(${info.container.name} ${info.bitrate.bitsPerSecond ~/ 1000}kbps)');
      return info.url.toString();
    } catch (e) {
      debugPrint('[YoutubeStreamService] ✗ getAudioUrl failed for $videoId: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  /// Downloads audio for [videoId] directly to [filePath].
  Future<void> downloadToFile(
    String videoId,
    String filePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _pickBestAudio(manifest);
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
      debugPrint('[YoutubeStreamService] ✓ Downloaded $videoId → $filePath');
    } catch (e) {
      debugPrint('[YoutubeStreamService] ✗ downloadToFile failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  /// Picks the best audio stream: prefers AAC/MP4 for compatibility,
  /// falls back to the highest-bitrate stream of any container.
  AudioStreamInfo _pickBestAudio(StreamManifest manifest) {
    final mp4Streams = manifest.audioOnly
        .where((s) => s.container.name.toLowerCase() == 'mp4')
        .toList();

    if (mp4Streams.isNotEmpty) {
      return mp4Streams.reduce(
        (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b,
      );
    }
    return manifest.audioOnly.withHighestBitrate();
  }
}

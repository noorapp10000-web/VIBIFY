import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// User-Agent used by the YouTube Android app (matches InnerTube ANDROID client).
/// Must be passed to ExoPlayer so YouTube CDN accepts range requests.
const kYoutubeAndroidUserAgent =
    'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip';

class YoutubeStreamService {
  // ──────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────

  /// Resolves a playable audio URL for [videoId].
  ///
  /// Strategy 1 – youtube_explode_dart (fast, reliable on real devices).
  /// Strategy 2 – InnerTube ANDROID direct (fallback if explode fails).
  ///
  /// Returns `null` only when both strategies fail.
  Future<String?> getAudioUrl(String videoId) async {
    // ── Strategy 1: youtube_explode_dart ────────────────────────
    try {
      final url = await _resolveViaExplode(videoId);
      if (url != null) {
        debugPrint('[Stream] ✓ Strategy 1 (yt-explode) succeeded');
        return url;
      }
    } catch (e) {
      debugPrint('[Stream] Strategy 1 failed: $e');
    }

    // ── Strategy 2: InnerTube ANDROID direct ────────────────────
    try {
      final url = await _resolveViaInnerTube(videoId);
      if (url != null) {
        debugPrint('[Stream] ✓ Strategy 2 (InnerTube) succeeded');
        return url;
      }
    } catch (e) {
      debugPrint('[Stream] Strategy 2 failed: $e');
    }

    debugPrint('[Stream] ✗ All strategies failed for $videoId');
    return null;
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
      debugPrint('[Stream] ✓ Downloaded $videoId → $filePath');
    } catch (e) {
      debugPrint('[Stream] ✗ downloadToFile failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Strategy 1: youtube_explode_dart
  // ──────────────────────────────────────────────────────────────

  Future<String?> _resolveViaExplode(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _pickBestAudio(manifest);
      final url = info.url.toString();
      debugPrint(
          '[Stream] explode: ${info.container.name} '
          '${info.bitrate.bitsPerSecond ~/ 1000}kbps');
      return url;
    } finally {
      yt.close();
    }
  }

  /// Picks the best audio stream: prefers AAC/MP4 for Android compatibility,
  /// falls back to the highest-bitrate stream of any container.
  AudioStreamInfo _pickBestAudio(StreamManifest manifest) {
    final mp4 = manifest.audioOnly
        .where((s) => s.container.name.toLowerCase() == 'mp4')
        .toList();
    if (mp4.isNotEmpty) {
      return mp4.reduce(
          (a, b) => a.bitrate.bitsPerSecond > b.bitrate.bitsPerSecond ? a : b);
    }
    return manifest.audioOnly.withHighestBitrate();
  }

  // ──────────────────────────────────────────────────────────────
  // Strategy 2: InnerTube ANDROID direct
  // ──────────────────────────────────────────────────────────────
  // InnerTube ANDROID returns unencrypted (no JS cipher) stream URLs.
  // These URLs are valid from real Android device IPs without datacenter blocks.

  Future<String?> _resolveViaInnerTube(String videoId) async {
    const endpoint =
        'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

    final body = jsonEncode({
      'videoId': videoId,
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '19.09.37',
          'androidSdkVersion': 30,
          'userAgent': kYoutubeAndroidUserAgent,
          'hl': 'en',
          'gl': 'US',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        },
      },
      'contentCheckOk': true,
      'racyCheckOk': true,
    });

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'User-Agent': kYoutubeAndroidUserAgent,
            'X-Goog-Api-Key': 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w',
            'Origin': 'https://www.youtube.com',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('[Stream] InnerTube HTTP ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final status =
        (data['playabilityStatus'] as Map?)?.['status'] as String?;
    if (status != 'OK') {
      debugPrint('[Stream] InnerTube playabilityStatus=$status');
      return null;
    }

    final formats =
        ((data['streamingData'] as Map?)?.['adaptiveFormats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((f) {
      final mime = (f['mimeType'] as String?) ?? '';
      return mime.startsWith('audio/');
    }).toList();

    if (formats == null || formats.isEmpty) {
      debugPrint('[Stream] InnerTube: no audio formats found');
      return null;
    }

    // Prefer AAC (mp4), fallback to any audio format
    final mp4 = formats
        .where((f) =>
            ((f['mimeType'] as String?) ?? '').contains('mp4'))
        .toList();
    final candidates = mp4.isNotEmpty ? mp4 : formats;

    candidates.sort((a, b) =>
        ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));

    final url = candidates.first['url'] as String?;
    if (url != null) {
      final bitrate = (candidates.first['bitrate'] as int?) ?? 0;
      debugPrint(
          '[Stream] InnerTube: ${candidates.first['mimeType']} ${bitrate ~/ 1000}kbps');
    }
    return url;
  }
}

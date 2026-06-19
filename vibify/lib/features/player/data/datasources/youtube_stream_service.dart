import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// User-Agent that matches the InnerTube ANDROID client.
/// Must also be passed to ExoPlayer so YouTube CDN accepts range requests.
const kYoutubeAndroidUserAgent =
    'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip';

class YoutubeStreamService {
  // ──────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────

  /// Returns a playable audio URL + headers for [videoId].
  ///
  /// Strategy 1 – InnerTube ANDROID direct (no JS-cipher risk, unencrypted URLs).
  /// Strategy 2 – youtube_explode_dart fallback.
  ///
  /// Returns `null` only when both strategies fail.
  Future<ResolvedStream?> resolveStream(String videoId) async {
    // ── Strategy 1: InnerTube ANDROID direct ────────────────────
    try {
      final url = await _resolveViaInnerTube(videoId);
      if (url != null) {
        debugPrint('[Stream] ✓ Strategy 1 (InnerTube ANDROID) ok');
        return ResolvedStream(
          url: Uri.parse(url),
          headers: {'User-Agent': kYoutubeAndroidUserAgent},
        );
      }
    } catch (e) {
      debugPrint('[Stream] Strategy 1 failed: $e');
    }

    // ── Strategy 2: youtube_explode_dart ────────────────────────
    try {
      final url = await _resolveViaExplode(videoId);
      if (url != null) {
        debugPrint('[Stream] ✓ Strategy 2 (yt-explode) ok');
        return ResolvedStream(
          url: Uri.parse(url),
          headers: {'User-Agent': kYoutubeAndroidUserAgent},
        );
      }
    } catch (e) {
      debugPrint('[Stream] Strategy 2 failed: $e');
    }

    debugPrint('[Stream] ✗ Both strategies failed for $videoId');
    return null;
  }

  /// Downloads audio for [videoId] directly to [filePath].
  ///
  /// Strategy 1 – InnerTube ANDROID direct URL + Dio (no cipher, real device IP).
  /// Strategy 2 – youtube_explode_dart fallback.
  Future<void> downloadToFile(
    String videoId,
    String filePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    // ── Strategy 1: InnerTube ANDROID → Dio download ────────────
    try {
      final url = await _resolveViaInnerTube(videoId);
      if (url != null) {
        debugPrint('[Download] ✓ Strategy 1 (InnerTube) — downloading…');
        await _downloadViaUrl(
          url,
          filePath,
          headers: {'User-Agent': kYoutubeAndroidUserAgent},
          onProgress: onProgress,
        );
        debugPrint('[Download] ✓ Done → $filePath');
        return;
      }
    } catch (e) {
      debugPrint('[Download] Strategy 1 failed: $e');
    }

    // ── Strategy 2: youtube_explode_dart fallback ────────────────
    debugPrint('[Download] Falling back to youtube_explode_dart…');
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
      debugPrint('[Download] ✓ Strategy 2 done → $filePath');
    } catch (e) {
      debugPrint('[Download] ✗ Both strategies failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  /// Downloads from a direct URL using Dio with progress tracking.
  Future<void> _downloadViaUrl(
    String url,
    String filePath, {
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    final dio = dio_lib.Dio(
      dio_lib.BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
        headers: headers != null
            ? Map<String, dynamic>.from(headers)
            : null,
      ),
    );
    await dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received, total);
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Strategy 1: InnerTube ANDROID direct
  // ──────────────────────────────────────────────────────────────
  // ANDROID client returns unencrypted URLs — no JS cipher needed.
  // Works from real device IPs without datacenter blocks.

  Future<String?> _resolveViaInnerTube(String videoId) async {
    const endpoint =
        'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'User-Agent': kYoutubeAndroidUserAgent,
            'X-Goog-Api-Key': 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w',
          },
          body: jsonEncode({
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
          }),
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
      final reason =
          (data['playabilityStatus'] as Map?)?.['reason'] as String? ?? '';
      debugPrint('[Stream] InnerTube status=$status reason=$reason');
      return null;
    }

    final formats =
        ((data['streamingData'] as Map?)?.['adaptiveFormats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((f) =>
                ((f['mimeType'] as String?) ?? '').startsWith('audio/') &&
                f['url'] != null)
            .toList();

    if (formats == null || formats.isEmpty) {
      debugPrint('[Stream] InnerTube: no direct audio URLs found');
      return null;
    }

    // Prefer AAC (audio/mp4), then anything else
    final mp4 = formats
        .where((f) => ((f['mimeType'] as String?) ?? '').contains('mp4'))
        .toList();
    final ranked = mp4.isNotEmpty ? mp4 : formats;
    ranked.sort((a, b) =>
        ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));

    final url = ranked.first['url'] as String;
    debugPrint(
        '[Stream] InnerTube: ${ranked.first['mimeType']} '
        '${((ranked.first['bitrate'] as int?) ?? 0) ~/ 1000}kbps');
    return url;
  }

  // ──────────────────────────────────────────────────────────────
  // Strategy 2: youtube_explode_dart
  // ──────────────────────────────────────────────────────────────

  Future<String?> _resolveViaExplode(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _pickBestAudio(manifest);
      debugPrint(
          '[Stream] explode: ${info.container.name} '
          '${info.bitrate.bitsPerSecond ~/ 1000}kbps');
      return info.url.toString();
    } finally {
      yt.close();
    }
  }

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
}

/// Holds the resolved stream URL and headers needed for playback.
class ResolvedStream {
  final Uri url;
  final Map<String, String> headers;
  const ResolvedStream({required this.url, required this.headers});
}

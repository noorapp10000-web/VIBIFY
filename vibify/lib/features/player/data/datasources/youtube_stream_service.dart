import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _kAndroidUserAgent =
    'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip';

const _kInnerTubeEndpoint =
    'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

const _kInnerTubeApiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';

class YoutubeStreamService {
  /// Resolves a direct audio URL for [videoId].
  /// Strategy 1: InnerTube ANDROID (unencrypted URLs, no cipher).
  /// Strategy 2: youtube_explode_dart fallback.
  Future<ResolvedStream?> resolveStream(String videoId) async {
    try {
      final url = await _innerTubeAudioUrl(videoId);
      if (url != null) {
        debugPrint('[Stream] InnerTube ok');
        return ResolvedStream(
          url: Uri.parse(url),
          headers: {'User-Agent': _kAndroidUserAgent},
        );
      }
    } catch (e) {
      debugPrint('[Stream] InnerTube failed: $e');
    }

    try {
      final url = await _explodeAudioUrl(videoId);
      if (url != null) {
        debugPrint('[Stream] yt-explode ok');
        return ResolvedStream(
          url: Uri.parse(url),
          headers: {'User-Agent': _kAndroidUserAgent},
        );
      }
    } catch (e) {
      debugPrint('[Stream] yt-explode failed: $e');
    }

    debugPrint('[Stream] Both strategies failed for $videoId');
    return null;
  }

  /// Downloads audio for [videoId] to [filePath] with optional progress.
  /// Strategy 1: InnerTube ANDROID + Dio.
  /// Strategy 2: youtube_explode_dart stream.
  Future<void> downloadToFile(
    String videoId,
    String filePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final url = await _innerTubeAudioUrl(videoId);
      if (url != null) {
        debugPrint('[Download] InnerTube ok — starting Dio download');
        await _dioDownload(url, filePath, onProgress: onProgress);
        debugPrint('[Download] Done → $filePath');
        return;
      }
    } catch (e) {
      debugPrint('[Download] InnerTube failed: $e');
    }

    debugPrint('[Download] Falling back to yt-explode');
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _bestAudio(manifest);
      final total = info.size.totalBytes;
      final stream = yt.videos.streamsClient.get(info);
      final sink = File(filePath).openWrite();
      int received = 0;
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      debugPrint('[Download] yt-explode done → $filePath');
    } catch (e) {
      debugPrint('[Download] Both strategies failed: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  Future<String?> _innerTubeAudioUrl(String videoId) async {
    final response = await http
        .post(
          Uri.parse(_kInnerTubeEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'User-Agent': _kAndroidUserAgent,
            'X-Goog-Api-Key': _kInnerTubeApiKey,
          },
          body: jsonEncode({
            'videoId': videoId,
            'context': {
              'client': {
                'clientName': 'ANDROID',
                'clientVersion': '19.09.37',
                'androidSdkVersion': 30,
                'userAgent': _kAndroidUserAgent,
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
      debugPrint('[InnerTube] HTTP ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final playability = data['playabilityStatus'] as Map<String, dynamic>?;
    final status = playability?['status'] as String?;

    if (status != 'OK') {
      final reason = playability?['reason'] as String? ?? '';
      debugPrint('[InnerTube] status=$status reason=$reason');
      return null;
    }

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    final adaptiveFormats =
        (streamingData?['adaptiveFormats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((f) =>
                (f['mimeType'] as String? ?? '').startsWith('audio/') &&
                f['url'] != null)
            .toList();

    if (adaptiveFormats == null || adaptiveFormats.isEmpty) {
      debugPrint('[InnerTube] no direct audio URLs');
      return null;
    }

    final mp4 = adaptiveFormats
        .where((f) => (f['mimeType'] as String? ?? '').contains('mp4'))
        .toList();
    final ranked = mp4.isNotEmpty ? mp4 : adaptiveFormats;
    ranked.sort((a, b) =>
        ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));

    final best = ranked.first;
    debugPrint(
        '[InnerTube] ${best['mimeType']} '
        '${((best['bitrate'] as int?) ?? 0) ~/ 1000}kbps');
    return best['url'] as String;
  }

  Future<String?> _explodeAudioUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = _bestAudio(manifest);
      debugPrint(
          '[yt-explode] ${info.container.name} '
          '${info.bitrate.bitsPerSecond ~/ 1000}kbps');
      return info.url.toString();
    } finally {
      yt.close();
    }
  }

  Future<void> _dioDownload(
    String url,
    String filePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = dio_lib.Dio(
      dio_lib.BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
        headers: {'User-Agent': _kAndroidUserAgent},
      ),
    );
    await client.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received, total);
      },
    );
  }

  AudioStreamInfo _bestAudio(StreamManifest manifest) {
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

class ResolvedStream {
  final Uri url;
  final Map<String, String> headers;
  const ResolvedStream({required this.url, required this.headers});
}

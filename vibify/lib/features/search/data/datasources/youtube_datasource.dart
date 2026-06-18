import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

// InnerTube WEB — direct from device, no key required for basic requests
const String _kSearchUrl = 'https://www.youtube.com/youtubei/v1/search';

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Future<String?> getPipedStreamUrl(String videoId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  // InnerTube WEB client — fast, works on real device IPs
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'ar,en;q=0.9',
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com/',
    },
  ));

  // ── Search ────────────────────────────────────────────────────────────────
  // Uses InnerTube WEB client directly from the device.
  // No API key required — YouTube allows unauthenticated WEB search.

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    try {
      final tracks = await _searchInnerTube(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] InnerTube WEB ✓ ${tracks.length} نتيجة');
        return SearchResult(
          tracks: tracks,
          artists: [],
          playlists: [],
          query: query,
        );
      }
    } catch (e) {
      debugPrint('[Search] InnerTube WEB ✗ $e');
    }
    throw StreamException(
        message: 'البحث فشل. تحقق من الإنترنت وحاول مجدداً.');
  }

  Future<List<Track>> _searchInnerTube(String query, int limit) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      _kSearchUrl,
      data: {
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240101.01.00',
            'hl': 'ar',
            'gl': 'EG',
          }
        },
        'query': query,
        'params': 'EgIQAQ==', // فيديوهات فقط
      },
    );

    final sections = ((resp.data?['contents'] as Map?)
                ?['twoColumnSearchResultsRenderer'] as Map?)
            ?['primaryContents']
            ?['sectionListRenderer']
            ?['contents'] as List<dynamic>? ??
        [];

    final tracks = <Track>[];
    for (final section in sections) {
      final items =
          ((section['itemSectionRenderer'] as Map?)?['contents'] as List?) ??
              [];
      for (final item in items) {
        final vr = item['videoRenderer'] as Map?;
        if (vr == null) continue;
        final vid = vr['videoId'] as String?;
        if (vid == null || vid.isEmpty) continue;

        final title =
            ((vr['title'] as Map?)?['runs'] as List?)?.firstOrNull?['text']
                    as String? ??
                vid;
        final artist =
            ((vr['ownerText'] as Map?)?['runs'] as List?)?.firstOrNull?['text']
                    as String? ??
                'Unknown';
        final durText =
            (vr['lengthText'] as Map?)?['simpleText'] as String?;

        tracks.add(Track(
          id: vid,
          title: title,
          artist: artist,
          duration: _parseDuration(durText),
          thumbnailUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          source: TrackSource.youtube,
          youtubeVideoId: vid,
          addedAt: DateTime.now(),
        ));
        if (tracks.length >= limit) break;
      }
      if (tracks.length >= limit) break;
    }
    return tracks;
  }

  // ── Track details ─────────────────────────────────────────────────────────

  @override
  Future<Track> getTrackDetails(String videoId) async {
    return Track(
      id: videoId,
      title: videoId,
      artist: 'Unknown',
      duration: null,
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      source: TrackSource.youtube,
      youtubeVideoId: videoId,
      addedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async => [];

  /// Stream URL via InnerTube ANDROID — same protocol as the YouTube app.
  /// Falls back gracefully if blocked (e.g. on server/datacenter IPs).
  @override
  Future<String?> getPipedStreamUrl(String videoId) async {
    // Delegate to the audio handler's stream resolution via InnerTube ANDROID.
    // This method is called from the debug test button only;
    // actual playback goes through VibifyAudioHandler.resolveYoutubeStream().
    try {
      final resp = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent':
              'com.google.android.youtube/19.09.37 (Linux; U; Android 12; GB) gzip',
          'X-YouTube-Client-Name': '3',
          'X-YouTube-Client-Version': '19.09.37',
        },
      )).post<Map<String, dynamic>>(
        'https://www.youtube.com/youtubei/v1/player'
        '?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w',
        data: {
          'context': {
            'client': {
              'clientName': 'ANDROID',
              'clientVersion': '19.09.37',
              'androidSdkVersion': 31,
              'hl': 'ar',
              'gl': 'EG',
              'utcOffsetMinutes': 120,
            }
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
          'params': 'CgIQBg==',
        },
      );

      final fmts = (resp.data?['streamingData']?['adaptiveFormats']
              as List<dynamic>?) ??
          [];
      final audio = fmts
          .whereType<Map<String, dynamic>>()
          .where((f) =>
              (f['mimeType'] as String? ?? '').startsWith('audio') &&
              f['url'] != null)
          .toList()
        ..sort((a, b) =>
            ((b['bitrate'] as num?) ?? 0)
                .compareTo((a['bitrate'] as num?) ?? 0));

      if (audio.isNotEmpty) {
        debugPrint('[StreamTest] InnerTube ANDROID ✓');
        return audio.first['url'] as String;
      }
      debugPrint('[StreamTest] InnerTube ANDROID: no direct streams '
          '(status=${resp.data?['playabilityStatus']?['status']})');
      return null;
    } catch (e) {
      debugPrint('[StreamTest] InnerTube ANDROID ✗ $e');
      return null;
    }
  }

  Duration? _parseDuration(String? text) {
    if (text == null) return null;
    try {
      final parts = text.trim().split(':').map(int.parse).toList();
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return null;
  }
}

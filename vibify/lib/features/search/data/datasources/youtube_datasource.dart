import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

const String _kApiBase = 'https://broken-unit-a21e.noor-app-8000.workers.dev';

const String _kInnerTubeUrl =
    'https://www.youtube.com/youtubei/v1/search'
    '?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

const Map<String, String> _kInnerTubeHeaders = {
  'Content-Type': 'application/json',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36',
  'Accept-Language': 'en-US,en;q=0.9',
  'X-YouTube-Client-Name': '1',
  'X-YouTube-Client-Version': '2.20240101.01.00',
};

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: Map<String, dynamic>.from(_kInnerTubeHeaders),
  ));

  final Dio _apiDio = Dio(BaseOptions(
    baseUrl: _kApiBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 50),
  ));

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    // Try server-side search first (yt_dlp — more reliable)
    try {
      final tracks = await _searchViaServer(query, limit);
      if (tracks.isNotEmpty) {
        return SearchResult(
          tracks: tracks,
          artists: [],
          playlists: [],
          query: query,
        );
      }
    } catch (_) {}

    // Fallback: InnerTube direct
    try {
      final tracks = await _searchInnerTube(query, limit);
      return SearchResult(
        tracks: tracks,
        artists: [],
        playlists: [],
        query: query,
      );
    } catch (e) {
      throw StreamException(message: 'Search failed: $e');
    }
  }

  Future<List<Track>> _searchViaServer(String query, int limit) async {
    final resp = await _apiDio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final data = resp.data ?? {};
    final rawTracks = (data['tracks'] as List<dynamic>?) ?? [];
    return rawTracks.map((item) {
      final m = item as Map<String, dynamic>;
      final vid = m['id'] as String? ?? '';
      final durationText = m['duration_text'] as String?;
      return Track(
        id: vid,
        title: m['title'] as String? ?? vid,
        artist: m['artist'] as String? ?? 'Unknown',
        duration: _parseDuration(durationText),
        thumbnailUrl: m['thumbnail_url'] as String?,
        source: TrackSource.youtube,
        youtubeVideoId: vid,
        addedAt: DateTime.now(),
      );
    }).toList();
  }

  Future<List<Track>> _searchInnerTube(String query, int limit) async {
    final payload = {
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20240101.01.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'query': query,
      'params': 'EgIQAQ%3D%3D',
    };

    final resp = await _dio.post<Map<String, dynamic>>(
      _kInnerTubeUrl,
      data: payload,
    );

    final data = resp.data ?? {};
    final contents = (((data['contents'] as Map?)
                ?['twoColumnSearchResultsRenderer'] as Map?)
            ?['primaryContents'] as Map?)
        ?['sectionListRenderer'];
    if (contents == null) return [];

    final sections = (contents['contents'] as List<dynamic>?) ?? [];
    final tracks = <Track>[];

    for (final section in sections) {
      final items = ((section['itemSectionRenderer'] as Map?)
              ?['contents'] as List<dynamic>?) ??
          [];
      for (final item in items) {
        final vr = item['videoRenderer'] as Map?;
        if (vr == null) continue;
        final vid = vr['videoId'] as String?;
        if (vid == null || vid.isEmpty) continue;

        final title = ((vr['title'] as Map?)?['runs'] as List?)
                ?.firstOrNull?['text'] as String? ??
            vid;
        final channel = ((vr['ownerText'] as Map?)?['runs'] as List?)
                ?.firstOrNull?['text'] as String? ??
            'Unknown';
        final durationText =
            (vr['lengthText'] as Map?)?['simpleText'] as String?;
        final duration = _parseDuration(durationText);
        final thumbUrl = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';

        tracks.add(Track(
          id: vid,
          title: title,
          artist: channel,
          duration: duration,
          thumbnailUrl: thumbUrl,
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

  Duration? _parseDuration(String? text) {
    if (text == null) return null;
    try {
      final parts = text.trim().split(':').map(int.parse).toList();
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
      if (parts.length == 3) {
        return Duration(
            hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Track> getTrackDetails(String videoId) async {
    try {
      final resp = await _apiDio.get<Map<String, dynamic>>(
        '/info',
        queryParameters: {'id': videoId},
      );
      final d = resp.data!;
      return _mapToTrack(d, videoId);
    } on DioException catch (e) {
      throw StreamException(
          message: 'Failed to get track details: ${e.message}');
    } catch (e) {
      throw StreamException(message: 'Failed to get track details: $e');
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    return [];
  }

  Track _mapToTrack(Map<String, dynamic> d, String videoId) {
    final durationSec = d['duration_seconds'] as num?;
    return Track(
      id: d['id'] as String? ?? videoId,
      title: d['title'] as String? ?? videoId,
      artist: d['artist'] as String? ?? 'Unknown',
      duration:
          durationSec != null ? Duration(seconds: durationSec.toInt()) : null,
      thumbnailUrl: d['thumbnail_url'] as String?,
      source: TrackSource.youtube,
      youtubeVideoId: d['youtube_video_id'] as String? ?? videoId,
      addedAt: DateTime.now(),
    );
  }
}

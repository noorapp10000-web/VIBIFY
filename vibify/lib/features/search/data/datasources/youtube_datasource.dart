import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

const String _kApiBase = 'https://yt-audio-api.noor-app-100.workers.dev';

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _kApiBase,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    try {
      debugPrint('[Search] Calling Cloudflare API → q="$query"');

      final resp = await _dio.get<dynamic>(
        '/api/search',
        queryParameters: {'q': query},
      );

      final dynamic data = resp.data;
      debugPrint('[Search] Response type: ${data.runtimeType}');

      List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map) {
        items = (data['results'] ??
                data['items'] ??
                data['videos'] ??
                []) as List<dynamic>;
      } else if (data is String) {
        // dio might return raw string if content-type header is wrong
        final decoded = json.decode(data);
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map) {
          items = (decoded['results'] ??
                  decoded['items'] ??
                  decoded['videos'] ??
                  []) as List<dynamic>;
        } else {
          items = [];
        }
      } else {
        items = [];
      }

      debugPrint('[Search] Parsed ${items.length} items');

      final tracks = <Track>[];
      for (final item in items) {
        if (item is! Map) continue;

        final videoId = item['videoId'] as String?;
        if (videoId == null || videoId.isEmpty) continue;

        final title = item['title'] as String? ?? videoId;
        final thumbnail = item['thumbnail'] as String? ??
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        final artist = item['author'] as String? ??
            item['channelTitle'] as String? ??
            item['channel'] as String? ??
            'Unknown';
        final durationRaw = item['duration'];

        Duration? duration;
        if (durationRaw is String && durationRaw.isNotEmpty) {
          duration = _parseDuration(durationRaw);
        } else if (durationRaw is int) {
          duration = Duration(seconds: durationRaw);
        }

        tracks.add(Track(
          id: videoId,
          title: title,
          artist: artist,
          duration: duration,
          thumbnailUrl: thumbnail,
          source: TrackSource.youtube,
          youtubeVideoId: videoId,
          addedAt: DateTime.now(),
        ));

        if (tracks.length >= limit) break;
      }

      debugPrint('[Search] Cloudflare API ✓ ${tracks.length} نتيجة');
      return SearchResult(
        tracks: tracks,
        artists: [],
        playlists: [],
        query: query,
      );
    } on DioException catch (e) {
      debugPrint('[Search] DioException: ${e.type} — ${e.message}');
      debugPrint('[Search] Response: ${e.response?.data}');
      throw StreamException(
          message: 'البحث فشل (${e.type.name}). تحقق من الإنترنت.');
    } catch (e) {
      debugPrint('[Search] Unexpected error: $e');
      throw StreamException(
          message: 'البحث فشل: $e');
    }
  }

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
}

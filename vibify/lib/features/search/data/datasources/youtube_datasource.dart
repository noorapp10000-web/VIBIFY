import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  final http.Client _client;

  YoutubeDatasourceImpl({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$_kApiBase/api/search')
          .replace(queryParameters: {'q': query});

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw StreamException(
            message: 'API returned ${response.statusCode}');
      }

      final dynamic decoded = json.decode(response.body);

      List<dynamic> items;
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

      final tracks = <Track>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;

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
    } catch (e) {
      debugPrint('[Search] Cloudflare API ✗ $e');
      throw StreamException(message: 'البحث فشل. تحقق من الإنترنت وحاول مجدداً.');
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

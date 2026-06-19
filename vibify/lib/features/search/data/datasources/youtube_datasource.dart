import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_kApiBase/api/search?q=${Uri.encodeQueryComponent(query)}',
      );
      debugPrint('[Search] → $uri');

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 15));

      final body = await resp.transform(utf8.decoder).join();
      debugPrint('[Search] HTTP ${resp.statusCode} — body length: ${body.length}');

      if (body.isEmpty) {
        debugPrint('[Search] ✗ Empty response body');
        throw StreamException(message: 'الاستجابة فارغة من السيرفر.');
      }

      dynamic decoded;
      try {
        decoded = json.decode(body);
      } catch (e) {
        debugPrint('[Search] ✗ JSON decode failed: $e');
        debugPrint('[Search] Raw body (first 300): ${body.substring(0, body.length.clamp(0, 300))}');
        throw StreamException(message: 'فشل تحليل الـ JSON: $e');
      }

      debugPrint('[Search] Decoded type: ${decoded.runtimeType}');

      List<dynamic> items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map) {
        // Log the actual keys to understand the response
        debugPrint('[Search] Response keys: ${decoded.keys.toList()}');
        final rawList = decoded['results'] ??
            decoded['items'] ??
            decoded['videos'] ??
            decoded['data'];
        if (rawList == null) {
          debugPrint('[Search] ✗ No known list key found. Keys: ${decoded.keys}');
          if (decoded.containsKey('error')) {
            throw StreamException(message: 'السيرفر أعاد خطأ: ${decoded['error']}');
          }
          items = [];
        } else {
          items = List<dynamic>.from(rawList as List);
        }
      } else {
        debugPrint('[Search] ✗ Unexpected decoded type: ${decoded.runtimeType}');
        items = [];
      }

      debugPrint('[Search] Items count: ${items.length}');

      final tracks = <Track>[];
      for (final item in items) {
        if (item is! Map) {
          debugPrint('[Search] Skipping non-Map item: ${item.runtimeType}');
          continue;
        }

        final videoId = (item['videoId'] ?? item['id'] ?? item['video_id'])?.toString();
        if (videoId == null || videoId.isEmpty) {
          debugPrint('[Search] Skipping item with no videoId: $item');
          continue;
        }

        final title = (item['title'] ?? videoId).toString();
        final thumbnail = (item['thumbnail'] ??
                item['thumbnailUrl'] ??
                item['thumb'] ??
                'https://i.ytimg.com/vi/$videoId/hqdefault.jpg')
            .toString();
        final artist = (item['author'] ??
                item['channelTitle'] ??
                item['channel'] ??
                item['uploader'] ??
                'Unknown')
            .toString();
        final durationRaw = item['duration'];

        Duration? duration;
        if (durationRaw is String && durationRaw.isNotEmpty) {
          duration = _parseDuration(durationRaw);
        } else if (durationRaw is int) {
          duration = Duration(seconds: durationRaw);
        } else if (durationRaw is double) {
          duration = Duration(seconds: durationRaw.toInt());
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

      debugPrint('[Search] ✓ ${tracks.length} tracks parsed');
      return SearchResult(
        tracks: tracks,
        artists: [],
        playlists: [],
        query: query,
      );
    } on StreamException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[Search] SocketException: $e');
      throw StreamException(message: 'لا يوجد اتصال بالإنترنت.');
    } on TimeoutException catch (e) {
      debugPrint('[Search] Timeout: $e');
      throw StreamException(message: 'انتهت مهلة الطلب. حاول مجدداً.');
    } catch (e) {
      debugPrint('[Search] Unexpected error: $e');
      throw StreamException(message: 'خطأ غير متوقع: $e');
    }
  }

  @override
  Future<Track> getTrackDetails(String videoId) async {
    return Track(
      id: videoId,
      title: videoId,
      artist: 'Unknown',
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
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return null;
  }
}

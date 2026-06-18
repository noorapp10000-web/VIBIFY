import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

// Piped API instances — used for stream URL fetching only (not search).
// Tried in order; instances go up/down so we keep a short list.
const List<String> _kPipedInstances = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.adminforge.de',
  'https://api.piped.yt',
  'https://piped-api.cass.si',
  'https://pipedapi.reallyaweso.me',
  'https://pipedapi.aeong.one',
  'https://piped-api.mint.lgbt',
];

// Direct InnerTube search (WEB client — works on real Android device IPs)
const String _kInnerTubeSearchUrl =
    'https://www.youtube.com/youtubei/v1/search';

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Future<String?> getPipedStreamUrl(String videoId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  // youtube_explode_dart — pure Dart YouTube extractor (no server needed)
  final YoutubeExplode _yt = YoutubeExplode();

  // InnerTube WEB search client
  final Dio _innerTubeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  // Piped Dio — short timeouts so failures are fast
  Dio _pipedDioFor(String base) => Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
        headers: {'Accept': 'application/json'},
      ));

  // ── Search ────────────────────────────────────────────────────────────────
  // Chain: InnerTube WEB → youtube_explode_dart
  // Both run on the device IP — fast, reliable, no external servers needed.

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    // ── 1. InnerTube WEB (fastest — direct from device) ──────────────────
    try {
      final tracks = await _searchInnerTube(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] InnerTube WEB ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] InnerTube WEB failed: $e');
    }

    // ── 2. youtube_explode_dart (pure Dart, handles all YouTube quirks) ──
    try {
      final tracks = await _searchViaYoutubeExplode(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] youtube_explode_dart ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] youtube_explode_dart failed: $e');
    }

    throw StreamException(
        message: 'Search failed. Check your internet connection and try again.');
  }

  SearchResult _result(List<Track> tracks, String query) => SearchResult(
        tracks: tracks,
        artists: [],
        playlists: [],
        query: query,
      );

  // ── InnerTube WEB search ──────────────────────────────────────────────────

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
      'params': 'EgIQAQ==', // videos only
    };

    final resp = await _innerTubeDio.post<Map<String, dynamic>>(
      _kInnerTubeSearchUrl,
      data: payload,
    );

    final contents = (((resp.data?['contents'] as Map?)
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

        tracks.add(Track(
          id: vid,
          title: title,
          artist: channel,
          duration: _parseDuration(durationText),
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

  // ── youtube_explode_dart search ───────────────────────────────────────────

  Future<List<Track>> _searchViaYoutubeExplode(
      String query, int limit) async {
    final results = await _yt.search
        .search(query)
        .timeout(const Duration(seconds: 20));

    final tracks = <Track>[];
    for (final video in results) {
      final vid = video.id.value;
      tracks.add(Track(
        id: vid,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        source: TrackSource.youtube,
        youtubeVideoId: vid,
        addedAt: DateTime.now(),
      ));
      if (tracks.length >= limit) break;
    }
    return tracks;
  }

  // ── Piped stream URL (for getPipedStreamUrl, on-demand use) ──────────────

  /// Fetches a fresh direct audio URL from Piped for [videoId].
  /// Tries each instance in order. Falls back to youtube_explode_dart.
  /// NEVER cache — URLs expire within minutes.
  @override
  Future<String?> getPipedStreamUrl(String videoId) async {
    // Try Piped instances first
    for (final base in _kPipedInstances) {
      try {
        final resp = await _pipedDioFor(base).get<Map<String, dynamic>>(
          '/streams/$videoId',
        );

        final audioStreams =
            (resp.data?['audioStreams'] as List<dynamic>?) ?? [];
        if (audioStreams.isEmpty) continue;

        final sorted = audioStreams
            .whereType<Map<String, dynamic>>()
            .where((s) => (s['url'] as String?)?.isNotEmpty == true)
            .toList()
          ..sort((a, b) => ((b['bitrate'] as num?) ?? 0)
              .compareTo((a['bitrate'] as num?) ?? 0));

        if (sorted.isEmpty) continue;

        final url = sorted.first['url'] as String;
        debugPrint('[Piped Stream] ✓ $base');
        return url;
      } catch (e) {
        debugPrint('[Piped Stream] ✗ $base → $e');
      }
    }

    // Piped unavailable → fall back to youtube_explode_dart
    debugPrint('[Piped Stream] All instances failed → using youtube_explode_dart');
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 25));
      final audio = manifest.audioOnly.withHighestBitrate();
      final url = audio.url.toString();
      debugPrint('[Stream] youtube_explode_dart fallback ✓');
      return url;
    } catch (e) {
      debugPrint('[Stream] youtube_explode_dart fallback failed: $e');
      return null;
    }
  }

  // ── Track details ─────────────────────────────────────────────────────────

  @override
  Future<Track> getTrackDetails(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId)
          .timeout(const Duration(seconds: 15));
      return Track(
        id: videoId,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        source: TrackSource.youtube,
        youtubeVideoId: videoId,
        addedAt: DateTime.now(),
      );
    } catch (_) {}

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
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return null;
  }
}

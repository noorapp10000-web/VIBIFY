import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

// Piped API instances — tried in order until one returns valid JSON.
// Public instances go up/down; keep this list up-to-date.
const List<String> _kPipedInstances = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.adminforge.de',
  'https://api.piped.yt',
  'https://piped-api.cass.si',
  'https://pipedapi.reallyaweso.me',
  'https://pipedapi.aeong.one',
  'https://piped-api.mint.lgbt',
];

// Primary: HuggingFace Space (yt-dlp HTML scraping — not blocked like InnerTube API)
const String _kHfBase = 'https://seifooooooo-vibify-api.hf.space';

// Backup: Cloudflare Worker (InnerTube — occasionally blocked)
const String _kCfBase = 'https://broken-unit-a21e.noor-app-8000.workers.dev';

// Direct InnerTube search (WEB client — works on real Android device IPs)
const String _kInnerTubeUrl =
    'https://www.youtube.com/youtubei/v1/search'
    '?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
  Future<String?> getPipedStreamUrl(String videoId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  // Creates a short-lived Dio pointed at a specific Piped instance
  Dio _pipedDioFor(String base) => Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'Accept': 'application/json'},
      ));

  // Short-timeout Dio for device-side InnerTube (fast path)
  final Dio _innerTubeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12; Pixel 6) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-YouTube-Client-Name': '1',
      'X-YouTube-Client-Version': '2.20240101.01.00',
    },
  ));

  // HuggingFace Space (yt-dlp — robust search)
  final Dio _hfDio = Dio(BaseOptions(
    baseUrl: _kHfBase,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // Cloudflare Worker backup
  final Dio _cfDio = Dio(BaseOptions(
    baseUrl: _kCfBase,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
  ));

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    // ── 1. InnerTube WEB direct from device (fastest on real Android IPs) ──
    try {
      final tracks = await _searchInnerTube(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] InnerTube WEB ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] InnerTube WEB failed: $e');
    }

    // ── 2. Piped API — open-source YouTube proxy (reliable, no bot-detection) ──
    try {
      final tracks = await _searchViaPiped(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] Piped API ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] Piped API failed: $e');
    }

    // ── 3. HuggingFace Space — yt-dlp (HTML scraping, harder to block) ──
    try {
      final tracks = await _searchViaHF(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] HuggingFace yt-dlp ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] HuggingFace failed: $e');
    }

    // ── 4. Cloudflare Worker — InnerTube from server ──
    try {
      final tracks = await _searchViaCF(query, limit);
      if (tracks.isNotEmpty) {
        debugPrint('[Search] Cloudflare Worker ✓ (${tracks.length} results)');
        return _result(tracks, query);
      }
    } catch (e) {
      debugPrint('[Search] Cloudflare Worker failed: $e');
    }

    throw StreamException(
        message: 'Search failed: no results from any source. '
            'Check your internet connection and try again.');
  }

  SearchResult _result(List<Track> tracks, String query) => SearchResult(
        tracks: tracks,
        artists: [],
        playlists: [],
        query: query,
      );

  // ── Piped API (open-source YouTube proxy) ────────────────────────────────
  // Tries each instance in _kPipedInstances until one returns valid results.

  Future<List<Track>> _searchViaPiped(String query, int limit) async {
    for (final base in _kPipedInstances) {
      try {
        final resp = await _pipedDioFor(base).get<Map<String, dynamic>>(
          '/search',
          queryParameters: {'q': query, 'filter': 'all'},
        );

        final items = (resp.data?['items'] as List<dynamic>?) ?? [];
        final tracks = <Track>[];

        for (final item in items) {
          final m = item as Map<String, dynamic>?;
          if (m == null) continue;
          if (m['type'] != 'stream') continue;

          final rawUrl = m['url'] as String? ?? '';
          final videoId = Uri.tryParse(rawUrl)?.queryParameters['v'] ?? '';
          if (videoId.isEmpty) continue;

          tracks.add(Track(
            id: videoId,
            title: m['title'] as String? ?? videoId,
            artist: m['uploaderName'] as String? ?? 'Unknown',
            duration: (m['duration'] as num?) != null
                ? Duration(seconds: (m['duration'] as num).toInt())
                : null,
            thumbnailUrl: m['thumbnail'] as String? ??
                'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            source: TrackSource.youtube,
            youtubeVideoId: videoId,
            addedAt: DateTime.now(),
          ));
          if (tracks.length >= limit) break;
        }

        if (tracks.isNotEmpty) {
          debugPrint('[Piped Search] ✓ $base (${tracks.length} results)');
          return tracks;
        }
      } catch (e) {
        debugPrint('[Piped Search] ✗ $base → $e');
      }
    }
    return []; // all instances failed
  }

  /// Fetch a direct audio stream URL from Piped for [videoId].
  /// Tries every instance in [_kPipedInstances] until one works.
  /// Does NOT cache — URLs expire and must be fetched fresh on each play.
  @override
  Future<String?> getPipedStreamUrl(String videoId) async {
    for (final base in _kPipedInstances) {
      try {
        final resp = await _pipedDioFor(base).get<Map<String, dynamic>>(
          '/streams/$videoId',
        );

        final audioStreams =
            (resp.data?['audioStreams'] as List<dynamic>?) ?? [];
        if (audioStreams.isEmpty) continue;

        final sorted = List<Map<String, dynamic>>.from(
          audioStreams.whereType<Map<String, dynamic>>().where(
                (s) => (s['url'] as String?)?.isNotEmpty == true,
              ),
        )..sort((a, b) =>
            ((b['bitrate'] as num?) ?? 0)
                .compareTo((a['bitrate'] as num?) ?? 0));

        if (sorted.isEmpty) continue;

        final url = sorted.first['url'] as String;
        debugPrint('[Piped Stream] ✓ $base → ${url.substring(0, url.length.clamp(0, 80))}...');
        return url;
      } catch (e) {
        debugPrint('[Piped Stream] ✗ $base → $e');
      }
    }
    debugPrint('[Piped Stream] All instances failed for $videoId');
    return null;
  }

  // ── InnerTube WEB direct (device IP) ──────────────────────────────────────

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
      _kInnerTubeUrl,
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

  // ── HuggingFace Space (yt-dlp) ────────────────────────────────────────────

  Future<List<Track>> _searchViaHF(String query, int limit) async {
    final resp = await _hfDio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    return _parseTracks(resp.data ?? {});
  }

  // ── Cloudflare Worker ─────────────────────────────────────────────────────

  Future<List<Track>> _searchViaCF(String query, int limit) async {
    final resp = await _cfDio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    return _parseTracks(resp.data ?? {});
  }

  // ── Shared response parser ─────────────────────────────────────────────────

  List<Track> _parseTracks(Map<String, dynamic> data) {
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

  // ── Track details ─────────────────────────────────────────────────────────

  @override
  Future<Track> getTrackDetails(String videoId) async {
    // Try HuggingFace first, fallback to Cloudflare
    for (final dio in [_hfDio, _cfDio]) {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          '/info',
          queryParameters: {'id': videoId},
        );
        return _mapToTrack(resp.data!, videoId);
      } catch (_) {}
    }
    // Last resort: minimal track from video ID
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

  Duration? _parseDuration(String? text) {
    if (text == null) return null;
    try {
      final parts = text.trim().split(':').map(int.parse).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
    } catch (_) {}
    return null;
  }
}

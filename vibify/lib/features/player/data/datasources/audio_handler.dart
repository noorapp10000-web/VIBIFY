import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';

// InnerTube player endpoint
const String _kPlayerUrl =
    'https://www.youtube.com/youtubei/v1/player'
    '?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';

// Piped API instances — tried in order until one returns a valid audio URL.
// Public instances go up/down frequently; keep this list up-to-date.
const List<String> _kPipedInstances = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.adminforge.de',
  'https://api.piped.yt',
  'https://piped-api.cass.si',
  'https://pipedapi.reallyaweso.me',
  'https://pipedapi.aeong.one',
  'https://piped-api.mint.lgbt',
];


/// Holds either a direct stream URL or an embed URL for iframe/webview fallback.
class StreamResolution {
  final String? directUrl;
  final String? embedUrl;
  final String? nocookieEmbedUrl;
  final String source;

  const StreamResolution({
    this.directUrl,
    this.embedUrl,
    this.nocookieEmbedUrl,
    required this.source,
  });

  bool get hasDirectUrl => directUrl != null && directUrl!.isNotEmpty;
  bool get hasEmbedFallback => embedUrl != null;
}

class VibifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final Dio _innerTubeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 12; GB) gzip',
    },
  ));
  // Creates a short-lived Dio for a specific Piped instance.
  // Short timeouts so a dead instance fails fast instead of blocking.
  Dio _pipedDioFor(String base) => Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
        headers: {'Accept': 'application/json'},
      ));

  // Track queue index ourselves — _player.currentIndex is always 0
  // because we load individual AudioSources, not a ConcatenatingAudioSource.
  int _currentQueueIndex = 0;

  // Last embed URL for iframe/webview fallback
  String? lastEmbedUrl;
  String? lastNocookieEmbedUrl;

  VibifyAudioHandler._({required AudioPlayer player}) : _player = player;

  /// Creates the handler and awaits AudioService.init() so the media session
  /// and lock-screen / notification controls are registered before playback.
  static Future<VibifyAudioHandler> createAndInit() async {
    final handler = VibifyAudioHandler._(player: AudioPlayer());

    try {
      await AudioService.init(
        builder: () => handler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.vibify.audio',
          androidNotificationChannelName: 'Vibify',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          notificationColor: Color(0xFFD6B48A),
          androidNotificationIcon: 'drawable/ic_notification',
          androidNotificationChannelDescription: 'Vibify music playback',
        ),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[AudioService] init error: $e');
    }

    handler._listenToPlayerEvents();
    return handler;
  }

  void _listenToPlayerEvents() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleTrackCompletion();
      }
    });

    _player.durationStream.listen((duration) {
      if (_currentQueueIndex < queue.value.length) {
        final updatedItem = queue.value[_currentQueueIndex].copyWith(
          duration: duration,
        );
        final newQueue = List<MediaItem>.from(queue.value);
        newQueue[_currentQueueIndex] = updatedItem;
        queue.add(newQueue);
      }
    });
  }

  void _handleTrackCompletion() {
    final repeatMode = playbackState.value.repeatMode;
    if (repeatMode == AudioServiceRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else if (_currentQueueIndex < queue.value.length - 1) {
      skipToNext();
    } else if (repeatMode == AudioServiceRepeatMode.all) {
      skipToQueueItem(0);
    } else {
      stop();
    }
  }

  Future<void> playTrack(Track track) async {
    final mediaItem = _trackToMediaItem(track);
    this.mediaItem.add(mediaItem);
    _currentQueueIndex = 0;
    queue.add([mediaItem]);

    if (track.source == TrackSource.youtube && track.youtubeVideoId != null) {
      await _playYoutubeTrack(track.youtubeVideoId!);
    } else if (track.source == TrackSource.local && track.localPath != null) {
      await _player.setFilePath(track.localPath!);
      await _player.play();
    }
  }

  // ── Stream resolution chain ──────────────────────────────────────────────
  // 1. InnerTube ANDROID — same protocol as the YouTube app; works on real
  //    Android device IPs; returns direct MP4/WEBM URLs without cipher.
  // 2. Piped API        — open-source proxy; fast-fail when instances are down.
  // 3. Embed fallback   — YouTube iframe/WebView as last resort.
  // ─────────────────────────────────────────────────────────────────────────

  Future<StreamResolution> resolveYoutubeStream(String videoId) async {
    // 1. InnerTube ANDROID (primary)
    try {
      final url = await _getStreamViaInnerTube(videoId);
      debugPrint('[Stream] InnerTube ANDROID ✓');
      return StreamResolution(directUrl: url, source: 'innertube_android');
    } catch (e) {
      debugPrint('[Stream] InnerTube failed: $e');
    }

    // 2. Piped API (4s timeout per instance — fails fast if all are down)
    try {
      final url = await _getStreamViaPiped(videoId);
      debugPrint('[Stream] Piped API ✓');
      return StreamResolution(directUrl: url, source: 'piped_api');
    } catch (e) {
      debugPrint('[Stream] Piped API failed: $e');
    }

    // 3. Embed fallback
    debugPrint('[Stream] All methods failed — embed fallback');
    return StreamResolution(
      embedUrl: 'https://www.youtube.com/embed/$videoId?autoplay=1',
      nocookieEmbedUrl:
          'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&controls=0&mute=0',
      source: 'embed_fallback',
    );
  }

  /// Try each Piped instance with a short timeout so failures are fast.
  Future<String> _getStreamViaPiped(String videoId) async {
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
        debugPrint('[Piped] ✓ $base');
        return url;
      } catch (e) {
        debugPrint('[Piped] ✗ $base → $e');
      }
    }
    throw Exception('Piped: all instances failed for $videoId');
  }

  Future<String> _getStreamViaInnerTube(String videoId) async {
    // Try multiple InnerTube clients in order — some bypass bot-detection better
    final clients = [
      {
        'clientName': 'ANDROID',
        'clientVersion': '19.29.34',
        'androidSdkVersion': 30,
        'hl': 'en',
        'gl': 'US',
        'userAgent': 'com.google.android.youtube/19.29.34 (Linux; U; Android 12; GB) gzip',
      },
      {
        'clientName': 'ANDROID_TESTSUITE',
        'clientVersion': '1.9',
        'androidSdkVersion': 30,
        'hl': 'en',
        'gl': 'US',
        'userAgent': 'com.google.android.youtube/1.9 (Linux; U; Android 12) gzip',
      },
      {
        'clientName': 'ANDROID',
        'clientVersion': '19.09.37',
        'androidSdkVersion': 30,
        'hl': 'en',
        'gl': 'US',
        'userAgent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 12; GB) gzip',
      },
    ];

    for (final client in clients) {
      try {
        final userAgent = client['userAgent'] as String;
        final clientCtx = Map<String, dynamic>.from(client)..remove('userAgent');

        final payload = {
          'videoId': videoId,
          'context': {'client': clientCtx},
          'params': '2AMBCgIQBg==',
        };

        final resp = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': userAgent,
          },
        )).post<Map<String, dynamic>>(_kPlayerUrl, data: payload);

        final streamingData = resp.data?['streamingData'] as Map?;
        if (streamingData == null) continue;

        final adaptive = (streamingData['adaptiveFormats'] as List<dynamic>?) ?? [];
        final allFormats = (streamingData['formats'] as List<dynamic>?) ?? [];

        final audioFormats = [...adaptive, ...allFormats]
            .whereType<Map>()
            .where((f) =>
                (f['mimeType'] as String? ?? '').startsWith('audio/') &&
                f['url'] != null &&
                f['signatureCipher'] == null)
            .toList();

        if (audioFormats.isNotEmpty) {
          audioFormats.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
              .compareTo((a['bitrate'] as num?) ?? 0));
          debugPrint('[Stream] InnerTube ${client['clientName']} ✓');
          return audioFormats.first['url'] as String;
        }

        // Combined formats as last resort
        final combined = [...adaptive, ...allFormats]
            .whereType<Map>()
            .where((f) => f['url'] != null && f['signatureCipher'] == null)
            .toList();
        if (combined.isNotEmpty) {
          debugPrint('[Stream] InnerTube ${client['clientName']} combined ✓');
          return combined.first['url'] as String;
        }
      } catch (e) {
        debugPrint('[Stream] ${client['clientName']} failed: $e');
        continue;
      }
    }

    throw Exception('All InnerTube clients returned no stream URL');
  }

  Future<void> _playYoutubeTrack(String videoId) async {
    try {
      final resolution = await resolveYoutubeStream(videoId);

      if (resolution.hasDirectUrl) {
        await _player.setAudioSource(
            AudioSource.uri(Uri.parse(resolution.directUrl!)));
        await _player.play();
        return;
      }

      // No direct URL — store embed URLs for UI to use (WebView iframe)
      lastEmbedUrl = resolution.embedUrl;
      lastNocookieEmbedUrl = resolution.nocookieEmbedUrl;
      debugPrint(
          '[Player] Embed fallback: ${resolution.embedUrl} (source=${resolution.source})');

      // Signal error state so UI can show iframe player
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    } catch (e) {
      debugPrint('[Player] All stream methods failed: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  Future<void> setQueueFromTracks(List<Track> tracks,
      {int startIndex = 0}) async {
    final mediaItems = tracks.map(_trackToMediaItem).toList();
    queue.add(mediaItems);
    _currentQueueIndex = startIndex.clamp(0, tracks.length - 1);
    await skipToQueueItem(_currentQueueIndex);
  }

  MediaItem _trackToMediaItem(Track track) => MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: track.thumbnailUrl != null
            ? Uri.parse(track.thumbnailUrl!)
            : null,
        extras: {
          'source': track.source.name,
          'localPath': track.localPath,
          'youtubeVideoId': track.youtubeVideoId,
        },
      );

  void _broadcastState(PlaybackEvent event) {
    final isPlaying = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: isPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentQueueIndex,
    ));
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentQueueIndex < queue.value.length - 1) {
      await skipToQueueItem(_currentQueueIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentQueueIndex > 0) {
      await skipToQueueItem(_currentQueueIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    _currentQueueIndex = index;
    final item = queue.value[index];
    mediaItem.add(item);

    final extras = item.extras;
    if (extras == null) return;

    final source = extras['source'] as String?;
    final youtubeVideoId = extras['youtubeVideoId'] as String?;
    final localPath = extras['localPath'] as String?;

    if (source == TrackSource.youtube.name && youtubeVideoId != null) {
      await _playYoutubeTrack(youtubeVideoId);
    } else if (source == TrackSource.local.name && localPath != null) {
      await _player.setFilePath(localPath);
      await _player.play();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = const {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
      AudioServiceRepeatMode.group: LoopMode.all,
    }[repeatMode]!;
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Called by the UI when the YouTube iframe WebView intercepts an audio URL.
  /// Feeds the URL directly into just_audio so playback can start.
  Future<void> injectIframeStreamUrl(String url) async {
    try {
      debugPrint('[IframeInject] Playing intercepted URL: ${url.substring(0, 80)}...');
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
    } catch (e) {
      debugPrint('[IframeInject] Failed to play injected URL: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  void dispose() {
    _player.dispose();
    _innerTubeDio.close();
  }
}

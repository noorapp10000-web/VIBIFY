import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';

// InnerTube ANDROID client — returns unencrypted stream URLs directly
// (no JS cipher needed), works on Android without bot-detection issues.
const String _kPlayerUrl =
    'https://www.youtube.com/youtubei/v1/player'
    '?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';

// HuggingFace fallback for resilience
const String _kApiBase = 'https://Seifooooooo-vibify-api.hf.space';

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
  final Dio _fallbackDio = Dio(BaseOptions(
    baseUrl: _kApiBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 40),
  ));

  // Track queue index ourselves — _player.currentIndex is always 0
  // because we load individual AudioSources, not a ConcatenatingAudioSource.
  int _currentQueueIndex = 0;

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
          androidStopForegroundOnPause: false,
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

  /// Gets audio stream URL using the InnerTube ANDROID client.
  /// The ANDROID client returns direct (unencrypted) URLs without JS cipher.
  /// Falls back to the HuggingFace server if InnerTube fails.
  Future<String> _getYoutubeStreamUrl(String videoId,
      {bool useFallback = false}) async {
    if (!useFallback) {
      try {
        return await _getStreamViaInnerTube(videoId);
      } catch (e) {
        debugPrint('[Stream] InnerTube failed: $e — trying server fallback');
      }
    }
    return await _getStreamViaServer(videoId);
  }

  Future<String> _getStreamViaInnerTube(String videoId) async {
    final payload = {
      'videoId': videoId,
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '19.09.37',
          'androidSdkVersion': 30,
          'hl': 'en',
          'gl': 'US',
        }
      },
    };

    final resp = await _innerTubeDio.post<Map<String, dynamic>>(
      _kPlayerUrl,
      data: payload,
    );

    final streamingData = resp.data?['streamingData'] as Map?;
    if (streamingData == null) throw Exception('No streamingData');

    // Try adaptive formats (audio-only) first for best quality
    final adaptive =
        (streamingData['adaptiveFormats'] as List<dynamic>?) ?? [];
    final audioFormats = adaptive
        .whereType<Map>()
        .where((f) =>
            (f['mimeType'] as String? ?? '').startsWith('audio/') &&
            f['url'] != null)
        .toList();

    if (audioFormats.isNotEmpty) {
      // Pick highest bitrate audio format
      audioFormats.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
          .compareTo((a['bitrate'] as num?) ?? 0));
      return audioFormats.first['url'] as String;
    }

    // Fallback: combined formats
    final formats = (streamingData['formats'] as List<dynamic>?) ?? [];
    final combined =
        formats.whereType<Map>().where((f) => f['url'] != null).toList();
    if (combined.isNotEmpty) {
      return combined.first['url'] as String;
    }

    throw Exception('No playable stream found in InnerTube response');
  }

  Future<String> _getStreamViaServer(String videoId) async {
    final resp = await _fallbackDio.get<Map<String, dynamic>>(
      '/stream',
      queryParameters: {'id': videoId},
    );
    final url = resp.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Server returned no stream URL for $videoId');
    }
    return url;
  }

  Future<void> _playYoutubeTrack(String videoId) async {
    try {
      final streamUrl = await _getYoutubeStreamUrl(videoId);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      await _player.play();
    } catch (e) {
      debugPrint('[Player] Primary stream failed: $e — trying fallback');
      try {
        final streamUrl =
            await _getYoutubeStreamUrl(videoId, useFallback: true);
        await _player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
        await _player.play();
      } catch (_) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
      }
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
    _fallbackDio.close();
  }
}

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';
import 'youtube_stream_service.dart';

class VibifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeStreamService _streamService;

  int _currentQueueIndex = 0;

  VibifyAudioHandler(this._streamService) {
    _listenToPlayerEvents();
  }

  static const AudioServiceConfig _serviceConfig = AudioServiceConfig(
    androidNotificationChannelId: 'com.vibify.audio',
    androidNotificationChannelName: 'Vibify',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    notificationColor: Color(0xFFD6B48A),
    androidNotificationIcon: 'drawable/ic_notification',
    androidNotificationChannelDescription: 'Vibify music playback',
  );

  static Future<VibifyAudioHandler> createAndInit(
      YoutubeStreamService streamService) async {
    try {
      return await AudioService.init<VibifyAudioHandler>(
        builder: () => VibifyAudioHandler(streamService),
        config: _serviceConfig,
      );
    } catch (e) {
      debugPrint('[AudioService] init failed ($e) — using plain handler');
      return VibifyAudioHandler(streamService);
    }
  }

  void _listenToPlayerEvents() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _handleTrackCompletion();
    });

    _player.durationStream.listen((duration) {
      if (_currentQueueIndex < queue.value.length) {
        final updated =
            queue.value[_currentQueueIndex].copyWith(duration: duration);
        final newQueue = List<MediaItem>.from(queue.value);
        newQueue[_currentQueueIndex] = updated;
        queue.add(newQueue);
      }
    });
  }

  void _handleTrackCompletion() {
    final mode = playbackState.value.repeatMode;
    if (mode == AudioServiceRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else if (_currentQueueIndex < queue.value.length - 1) {
      skipToNext();
    } else if (mode == AudioServiceRepeatMode.all) {
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
    await _playItem(track.source.name, track.youtubeVideoId, track.localPath);
  }

  Future<void> setQueueFromTracks(List<Track> tracks,
      {int startIndex = 0}) async {
    final items = tracks.map(_trackToMediaItem).toList();
    queue.add(items);
    _currentQueueIndex = startIndex.clamp(0, tracks.length - 1);
    await skipToQueueItem(_currentQueueIndex);
  }

  Future<void> _playItem(
      String source, String? youtubeId, String? localPath) async {
    if (source == TrackSource.youtube.name && youtubeId != null) {
      await _playYoutube(youtubeId);
    } else if (source == TrackSource.local.name && localPath != null) {
      await _player.setFilePath(localPath);
      await _player.play();
    }
  }

  Future<void> _playYoutube(String videoId) async {
    try {
      debugPrint('[Player] Resolving stream for $videoId…');

      // Set loading state so UI shows spinner immediately
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
      ));

      final resolved = await _streamService.resolveStream(videoId);
      if (resolved == null) {
        debugPrint('[Player] No stream resolved for $videoId');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ));
        return;
      }

      debugPrint('[Player] Got URL — loading…');
      await _player.setAudioSource(
        AudioSource.uri(resolved.url, headers: resolved.headers),
      );
      await _player.play();
      debugPrint('[Player] Playing $videoId');
    } catch (e, st) {
      debugPrint('[Player] Error for $videoId: $e\n$st');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  MediaItem _trackToMediaItem(Track track) => MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri:
            track.thumbnailUrl != null ? Uri.parse(track.thumbnailUrl!) : null,
        extras: {
          'source': track.source.name,
          'localPath': track.localPath,
          'youtubeVideoId': track.youtubeVideoId,
        },
      );

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
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
      playing: playing,
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
    await _playItem(
      extras['source'] as String? ?? '',
      extras['youtubeVideoId'] as String?,
      extras['localPath'] as String?,
    );
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
    playbackState
        .add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> setPlaybackSpeed(double speed) => _player.setSpeed(speed);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  void dispose() => _player.dispose();
}

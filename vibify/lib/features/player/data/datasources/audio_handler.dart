import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/track.dart';

class VibifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  int _currentQueueIndex = 0;

  VibifyAudioHandler() {
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

  /// Call once from main() — returns the handler wired to the system service.
  static Future<VibifyAudioHandler> createAndInit() async {
    return await AudioService.init<VibifyAudioHandler>(
      builder: VibifyAudioHandler.new,
      config: _serviceConfig,
    );
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

  Future<void> _playYoutubeTrack(String videoId) async {
    try {
      debugPrint('[Player] Resolving stream for $videoId via youtube_explode_dart…');
      final source = _YoutubeStreamAudioSource(videoId);
      await _player.setAudioSource(source);
      await _player.play();
      debugPrint('[Player] ✓ Playback started for $videoId');
    } catch (e) {
      debugPrint('[Player] ✗ Stream resolution failed for $videoId: $e');
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
  }
}

class _YoutubeStreamAudioSource extends StreamAudioSource {
  final String videoId;
  YoutubeExplode? _yt;

  _YoutubeStreamAudioSource(this.videoId) : super(tag: videoId);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    _yt?.close();
    final yt = YoutubeExplode();
    _yt = yt;

    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final info = manifest.audioOnly.withHighestBitrate();
      final totalBytes = info.size.totalBytes;
      final startByte = start ?? 0;
      final endByte = end ?? totalBytes;

      final stream = yt.videos.streamsClient.get(info);

      return StreamAudioResponse(
        sourceLength: totalBytes,
        contentLength: endByte - startByte,
        offset: startByte,
        stream: stream,
        contentType: 'audio/${info.container.name}',
      );
    } catch (e) {
      yt.close();
      _yt = null;
      rethrow;
    }
  }
}

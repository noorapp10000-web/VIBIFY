import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/player_state.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/player_repository.dart';
import '../datasources/audio_handler.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final VibifyAudioHandler _audioHandler;
  final StreamController<VibifyPlayerState> _stateController =
      StreamController.broadcast();

  VibifyPlayerState _currentState = const VibifyPlayerState();
  Timer? _sleepTimer;

  PlayerRepositoryImpl(this._audioHandler) {
    _listenToAudioHandler();
  }

  void _listenToAudioHandler() {
    _audioHandler.playbackState.listen(
      (playbackState) {
        final status = _mapProcessingState(
          playbackState.processingState,
          playbackState.playing,
        );
        _currentState = _currentState.copyWith(
          status: status,
          position: playbackState.position,
          isShuffling:
              playbackState.shuffleMode == AudioServiceShuffleMode.all,
          repeatMode: _mapRepeatMode(playbackState.repeatMode),
        );
        _stateController.add(_currentState);
      },
      onError: (_) {},
    );

    _audioHandler.mediaItem.listen(
      (item) {
        if (item != null) {
          _currentState = _currentState.copyWith(
            duration: item.duration ?? Duration.zero,
          );
          _stateController.add(_currentState);
        }
      },
      onError: (_) {},
    );

    _audioHandler.positionStream.listen(
      (position) {
        _currentState = _currentState.copyWith(position: position);
        _stateController.add(_currentState);
      },
      onError: (_) {},
    );
  }

  PlayerStatus _mapProcessingState(
    AudioProcessingState state,
    bool playing,
  ) {
    switch (state) {
      case AudioProcessingState.idle:
        return PlayerStatus.idle;
      case AudioProcessingState.loading:
      case AudioProcessingState.buffering:
        return PlayerStatus.loading;
      case AudioProcessingState.ready:
        return playing ? PlayerStatus.playing : PlayerStatus.paused;
      case AudioProcessingState.completed:
        return PlayerStatus.stopped;
      case AudioProcessingState.error:
        return PlayerStatus.error;
    }
  }

  RepeatMode _mapRepeatMode(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        return RepeatMode.none;
      case AudioServiceRepeatMode.one:
        return RepeatMode.one;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return RepeatMode.all;
    }
  }

  @override
  Stream<VibifyPlayerState> get playerStateStream => _stateController.stream;

  @override
  VibifyPlayerState get currentState => _currentState;

  @override
  Future<void> playTrack(Track track) async {
    final isFav = _isFavorite(track.id);
    _currentState = _currentState.copyWith(
      currentTrack: track,
      status: PlayerStatus.loading,
      isFavorite: isFav,
    );
    _stateController.add(_currentState);
    _saveHistory(track);
    await _audioHandler.playTrack(track);
  }

  bool _isFavorite(String trackId) {
    try {
      final box = Hive.box(AppConstants.favoritesBox);
      return box.containsKey(trackId);
    } catch (_) {
      return false;
    }
  }

  void _saveHistory(Track track) {
    try {
      final box = Hive.box(AppConstants.historyBox);
      final map = {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'thumbnailUrl': track.thumbnailUrl,
        'durationMs': track.duration?.inMilliseconds,
        'source': track.source.name,
        'localPath': track.localPath,
        'youtubeVideoId': track.youtubeVideoId,
      };
      box.delete(track.id);
      box.put(track.id, map);
    } catch (_) {}
  }

  @override
  Future<void> toggleFavorite(Track track) async {
    try {
      final box = Hive.box(AppConstants.favoritesBox);
      if (box.containsKey(track.id)) {
        await box.delete(track.id);
        _currentState = _currentState.copyWith(isFavorite: false);
      } else {
        await box.put(track.id, {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'thumbnailUrl': track.thumbnailUrl,
          'durationMs': track.duration?.inMilliseconds,
          'source': track.source.name,
          'localPath': track.localPath,
          'youtubeVideoId': track.youtubeVideoId,
        });
        _currentState = _currentState.copyWith(isFavorite: true);
      }
      _stateController.add(_currentState);
    } catch (_) {}
  }

  @override
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    final track = tracks.isNotEmpty ? tracks[startIndex] : null;
    final isFav = track != null ? _isFavorite(track.id) : false;
    _currentState = _currentState.copyWith(
      queue: tracks,
      currentIndex: startIndex,
      currentTrack: track,
      status: PlayerStatus.loading,
      isFavorite: isFav,
    );
    _stateController.add(_currentState);
    if (track != null) _saveHistory(track);
    await _audioHandler.setQueueFromTracks(tracks, startIndex: startIndex);
  }

  @override
  Future<void> pause() async => _audioHandler.pause();

  @override
  Future<void> resume() async => _audioHandler.play();

  @override
  Future<void> stop() async => _audioHandler.stop();

  @override
  Future<void> seek(Duration position) async => _audioHandler.seek(position);

  @override
  Future<void> skipToNext() async => _audioHandler.skipToNext();

  @override
  Future<void> skipToPrevious() async => _audioHandler.skipToPrevious();

  @override
  Future<void> skipToIndex(int index) async =>
      _audioHandler.skipToQueueItem(index);

  @override
  Future<void> addToQueue(Track track) async {
    final updatedQueue = List<Track>.from(_currentState.queue)..add(track);
    _currentState = _currentState.copyWith(queue: updatedQueue);
    _stateController.add(_currentState);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    final updatedQueue = List<Track>.from(_currentState.queue)..removeAt(index);
    _currentState = _currentState.copyWith(queue: updatedQueue);
    _stateController.add(_currentState);
  }

  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final updatedQueue = List<Track>.from(_currentState.queue);
    final track = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, track);
    _currentState = _currentState.copyWith(queue: updatedQueue);
    _stateController.add(_currentState);
  }

  @override
  Future<void> clearQueue() async {
    _currentState = _currentState.copyWith(queue: []);
    _stateController.add(_currentState);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    final serviceMode = {
      RepeatMode.none: AudioServiceRepeatMode.none,
      RepeatMode.one: AudioServiceRepeatMode.one,
      RepeatMode.all: AudioServiceRepeatMode.all,
    }[mode]!;
    await _audioHandler.setRepeatMode(serviceMode);
    _currentState = _currentState.copyWith(repeatMode: mode);
    _stateController.add(_currentState);
  }

  @override
  Future<void> toggleShuffle() async {
    final newShuffle = !_currentState.isShuffling;
    await _audioHandler.setShuffleMode(
      newShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
    _currentState = _currentState.copyWith(isShuffling: newShuffle);
    _stateController.add(_currentState);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _audioHandler.setPlaybackSpeed(speed);
    _currentState = _currentState.copyWith(playbackSpeed: speed);
    _stateController.add(_currentState);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _audioHandler.setVolume(volume);
    _currentState = _currentState.copyWith(volume: volume);
    _stateController.add(_currentState);
  }

  @override
  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () async {
      await stop();
    });
  }

  @override
  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }
}

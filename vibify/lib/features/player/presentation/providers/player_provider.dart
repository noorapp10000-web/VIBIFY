import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/player_state.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/usecases/manage_queue_usecase.dart';
import '../../domain/usecases/play_track_usecase.dart';
import '../../data/datasources/audio_handler.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) => sl<PlayerRepository>());

final playerStateProvider = StreamProvider<VibifyPlayerState>((ref) {
  final repo = ref.watch(playerRepositoryProvider);
  return repo.playerStateStream;
});

final currentPlayerStateProvider = Provider<VibifyPlayerState>((ref) {
  return ref.watch(playerStateProvider).valueOrNull ??
      const VibifyPlayerState();
});

final audioHandlerProvider = Provider<VibifyAudioHandler>((ref) => sl<VibifyAudioHandler>());

class PlayerNotifier extends StateNotifier<VibifyPlayerState> {
  final PlayerRepository _repository;
  final PlayTrackUsecase _playTrack;
  final ManageQueueUsecase _manageQueue;

  PlayerNotifier(this._repository, this._playTrack, this._manageQueue)
      : super(const VibifyPlayerState()) {
    _repository.playerStateStream.listen(
      (s) => state = s,
      onError: (_) {},
    );
  }

  Future<void> play(Track track) => _playTrack(track);

  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) =>
      _repository.playQueue(tracks, startIndex: startIndex);

  Future<void> pause() => _repository.pause();
  Future<void> resume() => _repository.resume();
  Future<void> stop() => _repository.stop();
  Future<void> seek(Duration position) => _repository.seek(position);
  Future<void> skipToNext() => _repository.skipToNext();
  Future<void> skipToPrevious() => _repository.skipToPrevious();
  Future<void> skipToIndex(int index) => _repository.skipToIndex(index);
  Future<void> addToQueue(Track track) => _manageQueue.addToQueue(track);
  Future<void> removeFromQueue(int index) =>
      _manageQueue.removeFromQueue(index);
  Future<void> clearQueue() => _manageQueue.clear();
  Future<void> toggleRepeat() {
    final next = {
      RepeatMode.none: RepeatMode.all,
      RepeatMode.all: RepeatMode.one,
      RepeatMode.one: RepeatMode.none,
    }[state.repeatMode]!;
    return _manageQueue.setRepeatMode(next);
  }

  Future<void> toggleShuffle() => _manageQueue.toggleShuffle();
  Future<void> setPlaybackSpeed(double speed) =>
      _manageQueue.setPlaybackSpeed(speed);
  Future<void> setSleepTimer(Duration duration) =>
      _manageQueue.setSleepTimer(duration);
  Future<void> cancelSleepTimer() => _manageQueue.cancelSleepTimer();
}

final playerNotifierProvider =
    StateNotifierProvider<PlayerNotifier, VibifyPlayerState>((ref) {
  return PlayerNotifier(
    sl<PlayerRepository>(),
    sl<PlayTrackUsecase>(),
    sl<ManageQueueUsecase>(),
  );
});

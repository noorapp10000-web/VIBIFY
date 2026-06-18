import '../entities/player_state.dart';
import '../entities/track.dart';
import '../repositories/player_repository.dart';

class ManageQueueUsecase {
  final PlayerRepository _repository;

  ManageQueueUsecase(this._repository);

  Future<void> addToQueue(Track track) => _repository.addToQueue(track);
  Future<void> removeFromQueue(int index) => _repository.removeFromQueue(index);
  Future<void> reorder(int oldIndex, int newIndex) =>
      _repository.reorderQueue(oldIndex, newIndex);
  Future<void> clear() => _repository.clearQueue();
  Future<void> setRepeatMode(RepeatMode mode) =>
      _repository.setRepeatMode(mode);
  Future<void> toggleShuffle() => _repository.toggleShuffle();
  Future<void> setPlaybackSpeed(double speed) =>
      _repository.setPlaybackSpeed(speed);
  Future<void> setSleepTimer(Duration duration) =>
      _repository.setSleepTimer(duration);
  Future<void> cancelSleepTimer() => _repository.cancelSleepTimer();
}

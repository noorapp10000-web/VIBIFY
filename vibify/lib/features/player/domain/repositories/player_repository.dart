import '../entities/track.dart';
import '../entities/player_state.dart';

abstract class PlayerRepository {
  Stream<VibifyPlayerState> get playerStateStream;
  VibifyPlayerState get currentState;

  Future<void> playTrack(Track track);
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);
  Future<void> addToQueue(Track track);
  Future<void> removeFromQueue(int index);
  Future<void> reorderQueue(int oldIndex, int newIndex);
  Future<void> clearQueue();
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> toggleShuffle();
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setSleepTimer(Duration duration);
  Future<void> cancelSleepTimer();
}

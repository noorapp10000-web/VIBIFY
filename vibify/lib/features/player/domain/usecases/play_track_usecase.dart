import '../entities/track.dart';
import '../repositories/player_repository.dart';
import '../../../../core/utils/usecase.dart';

class PlayTrackUsecase implements UseCase<void, Track> {
  final PlayerRepository _repository;

  PlayTrackUsecase(this._repository);

  @override
  Future<void> call(Track track) => _repository.playTrack(track);
}

class PlayQueueParams {
  final List<Track> tracks;
  final int startIndex;

  const PlayQueueParams({required this.tracks, this.startIndex = 0});
}

class PlayQueueUsecase implements UseCase<void, PlayQueueParams> {
  final PlayerRepository _repository;

  PlayQueueUsecase(this._repository);

  @override
  Future<void> call(PlayQueueParams params) =>
      _repository.playQueue(params.tracks, startIndex: params.startIndex);
}

import '../../../player/domain/entities/track.dart';
import '../repositories/local_music_repository.dart';
import '../../../../core/utils/usecase.dart';

class GetLocalTracksUsecase implements UseCaseNoParams<List<Track>> {
  final LocalMusicRepository _repository;

  GetLocalTracksUsecase(this._repository);

  @override
  Future<List<Track>> call() => _repository.getAllTracks();
}

import '../../../../core/network/network_info.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../../../player/domain/entities/track.dart';
import '../datasources/youtube_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  final YoutubeDatasource _datasource;
  final NetworkInfo _networkInfo;

  SearchRepositoryImpl(this._datasource, this._networkInfo);

  @override
  Future<SearchResult> search(String query, {int limit = 20}) =>
      _datasource.search(query, limit: limit);

  @override
  Future<Track> getTrackDetails(String videoId) =>
      _datasource.getTrackDetails(videoId);

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) =>
      _datasource.getPlaylistTracks(playlistId);
}

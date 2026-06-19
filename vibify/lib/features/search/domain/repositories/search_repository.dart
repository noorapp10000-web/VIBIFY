import '../entities/search_result.dart';
import '../../../player/domain/entities/track.dart';

abstract class SearchRepository {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
}

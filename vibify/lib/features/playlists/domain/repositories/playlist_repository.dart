import '../entities/playlist.dart';
import '../../../player/domain/entities/track.dart';

abstract class PlaylistRepository {
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylistById(String id);
  Future<Playlist> createPlaylist(String name, {String? description});
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<Playlist> addTrack(String playlistId, Track track);
  Future<Playlist> removeTrack(String playlistId, int index);
  Future<Playlist> reorderTracks(String playlistId, int oldIndex, int newIndex);
}

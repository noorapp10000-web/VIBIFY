import '../../../player/domain/entities/track.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/playlist_datasource.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistDatasource _datasource;

  PlaylistRepositoryImpl(this._datasource);

  @override
  Future<List<Playlist>> getAllPlaylists() => _datasource.getAllPlaylists();

  @override
  Future<Playlist?> getPlaylistById(String id) =>
      _datasource.getPlaylistById(id);

  @override
  Future<Playlist> createPlaylist(String name, {String? description}) =>
      _datasource.createPlaylist(name, description: description);

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) =>
      _datasource.updatePlaylist(playlist);

  @override
  Future<void> deletePlaylist(String id) => _datasource.deletePlaylist(id);

  @override
  Future<Playlist> addTrack(String playlistId, Track track) =>
      _datasource.addTrack(playlistId, track);

  @override
  Future<Playlist> removeTrack(String playlistId, int index) =>
      _datasource.removeTrack(playlistId, index);

  @override
  Future<Playlist> reorderTracks(
          String playlistId, int oldIndex, int newIndex) =>
      _datasource.reorderTracks(playlistId, oldIndex, newIndex);
}

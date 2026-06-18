import '../entities/playlist.dart';
import '../repositories/playlist_repository.dart';
import '../../../player/domain/entities/track.dart';

class PlaylistUsecases {
  final PlaylistRepository _repository;

  PlaylistUsecases(this._repository);

  Future<List<Playlist>> getAll() => _repository.getAllPlaylists();
  Future<Playlist?> getById(String id) => _repository.getPlaylistById(id);
  Future<Playlist> create(String name, {String? description}) =>
      _repository.createPlaylist(name, description: description);
  Future<Playlist> update(Playlist playlist) =>
      _repository.updatePlaylist(playlist);
  Future<void> delete(String id) => _repository.deletePlaylist(id);
  Future<Playlist> addTrack(String playlistId, Track track) =>
      _repository.addTrack(playlistId, track);
  Future<Playlist> removeTrack(String playlistId, int index) =>
      _repository.removeTrack(playlistId, index);
  Future<Playlist> reorderTracks(
          String playlistId, int oldIndex, int newIndex) =>
      _repository.reorderTracks(playlistId, oldIndex, newIndex);
}

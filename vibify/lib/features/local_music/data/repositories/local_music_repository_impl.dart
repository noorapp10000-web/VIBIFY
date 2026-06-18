import '../../../player/domain/entities/track.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../datasources/local_music_datasource.dart';

class LocalMusicRepositoryImpl implements LocalMusicRepository {
  final LocalMusicDatasource _datasource;

  LocalMusicRepositoryImpl(this._datasource);

  @override
  Future<bool> requestPermission() => _datasource.requestPermission();

  @override
  Future<List<Track>> getAllTracks() => _datasource.getAllTracks();

  @override
  Future<List<LocalAlbum>> getAllAlbums() => _datasource.getAllAlbums();

  @override
  Future<List<LocalArtist>> getAllArtists() => _datasource.getAllArtists();

  @override
  Future<List<LocalGenre>> getAllGenres() => _datasource.getAllGenres();

  @override
  Future<List<Track>> getTracksByAlbum(int albumId) =>
      _datasource.getTracksByAlbum(albumId);

  @override
  Future<List<Track>> getTracksByArtist(int artistId) =>
      _datasource.getTracksByArtist(artistId);

  @override
  Future<List<Track>> getTracksByFolder(String path) =>
      _datasource.getTracksByFolder(path);

  @override
  Future<List<String>> getAllFolders() => _datasource.getAllFolders();
}

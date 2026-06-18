import '../../../player/domain/entities/track.dart';
import '../../data/datasources/local_music_datasource.dart';

abstract class LocalMusicRepository {
  Future<bool> requestPermission();
  Future<List<Track>> getAllTracks();
  Future<List<LocalAlbum>> getAllAlbums();
  Future<List<LocalArtist>> getAllArtists();
  Future<List<LocalGenre>> getAllGenres();
  Future<List<Track>> getTracksByAlbum(int albumId);
  Future<List<Track>> getTracksByArtist(int artistId);
  Future<List<Track>> getTracksByFolder(String path);
  Future<List<String>> getAllFolders();
}

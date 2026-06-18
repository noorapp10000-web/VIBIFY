import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';

abstract class LocalMusicDatasource {
  Future<bool> requestPermission();
  Future<List<Track>> getAllTracks();
  Future<List<LocalAlbum>> getAllAlbums();
  Future<List<LocalArtist>> getAllArtists();
  Future<List<LocalGenre>> getAllGenres();
  Future<List<Track>> getTracksByAlbum(int albumId);
  Future<List<Track>> getTracksByArtist(int artistId);
  Future<List<Track>> getTracksByGenre(int genreId);
  Future<List<Track>> getTracksByFolder(String path);
  Future<List<String>> getAllFolders();
}

class LocalAlbum {
  final int id;
  final String name;
  final String? artist;
  final int numOfSongs;
  final String? artworkPath;

  const LocalAlbum({
    required this.id,
    required this.name,
    this.artist,
    required this.numOfSongs,
    this.artworkPath,
  });
}

class LocalArtist {
  final int id;
  final String name;
  final int numOfTracks;
  final int numOfAlbums;

  const LocalArtist({
    required this.id,
    required this.name,
    required this.numOfTracks,
    required this.numOfAlbums,
  });
}

class LocalGenre {
  final int id;
  final String name;
  final int numOfSongs;

  const LocalGenre({
    required this.id,
    required this.name,
    required this.numOfSongs,
  });
}

class LocalMusicDatasourceImpl implements LocalMusicDatasource {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final audioStatus = await Permission.audio.request();
      return audioStatus.isGranted;
    }
    return true;
  }

  @override
  Future<List<Track>> getAllTracks() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      return songs
          .where((s) => s.duration != null && s.duration! > 30000)
          .map(_songToTrack)
          .toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load local tracks: $e');
    }
  }

  @override
  Future<List<LocalAlbum>> getAllAlbums() async {
    try {
      final albums = await _audioQuery.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
      );
      return albums
          .map((a) => LocalAlbum(
                id: a.id,
                name: a.album,
                artist: a.artist,
                numOfSongs: a.numOfSongs,
              ))
          .toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load albums: $e');
    }
  }

  @override
  Future<List<LocalArtist>> getAllArtists() async {
    try {
      final artists = await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
      );
      return artists
          .map((a) => LocalArtist(
                id: a.id,
                name: a.artist,
                numOfTracks: a.numberOfTracks ?? 0,
                numOfAlbums: a.numberOfAlbums ?? 0,
              ))
          .toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load artists: $e');
    }
  }

  @override
  Future<List<LocalGenre>> getAllGenres() async {
    try {
      final genres = await _audioQuery.queryGenres(
        sortType: GenreSortType.GENRE,
        orderType: OrderType.ASC_OR_SMALLER,
      );
      return genres
          .map((g) => LocalGenre(
                id: g.id,
                name: g.genre,
                numOfSongs: g.numOfSongs ?? 0,
              ))
          .toList();
    } catch (e) {
      throw CacheException(message: 'Failed to load genres: $e');
    }
  }

  @override
  Future<List<Track>> getTracksByAlbum(int albumId) async {
    final songs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
    );
    return songs.map(_songToTrack).toList();
  }

  @override
  Future<List<Track>> getTracksByArtist(int artistId) async {
    final songs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ARTIST_ID,
      artistId,
    );
    return songs.map(_songToTrack).toList();
  }

  @override
  Future<List<Track>> getTracksByGenre(int genreId) async {
    final songs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.GENRE_ID,
      genreId,
    );
    return songs.map(_songToTrack).toList();
  }

  @override
  Future<List<Track>> getTracksByFolder(String path) async {
    final all = await getAllTracks();
    return all.where((t) => t.localPath?.startsWith(path) ?? false).toList();
  }

  @override
  Future<List<String>> getAllFolders() async {
    final tracks = await getAllTracks();
    final folders = <String>{};
    for (final track in tracks) {
      if (track.localPath != null) {
        final parts = track.localPath!.split('/');
        if (parts.length > 1) {
          parts.removeLast();
          folders.add(parts.join('/'));
        }
      }
    }
    return folders.toList()..sort();
  }

  Track _songToTrack(SongModel song) => Track(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        album: song.album,
        duration: song.duration != null
            ? Duration(milliseconds: song.duration!)
            : null,
        source: TrackSource.local,
        localPath: song.data,
        addedAt: song.dateAdded != null
            ? DateTime.fromMillisecondsSinceEpoch(song.dateAdded! * 1000)
            : null,
      );
}

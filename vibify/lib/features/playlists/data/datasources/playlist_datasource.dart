import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/playlist.dart';

abstract class PlaylistDatasource {
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylistById(String id);
  Future<Playlist> createPlaylist(String name, {String? description});
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
  Future<Playlist> addTrack(String playlistId, Track track);
  Future<Playlist> removeTrack(String playlistId, int index);
  Future<Playlist> reorderTracks(String playlistId, int oldIndex, int newIndex);
}

class PlaylistDatasourceImpl implements PlaylistDatasource {
  final Box _box;
  final _uuid = const Uuid();

  PlaylistDatasourceImpl(this._box);

  @override
  Future<List<Playlist>> getAllPlaylists() async {
    try {
      final playlists = <Playlist>[];
      for (final key in _box.keys) {
        final data = _box.get(key);
        if (data != null) {
          playlists.add(_fromMap(Map<String, dynamic>.from(data)));
        }
      }
      playlists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return playlists;
    } catch (e) {
      throw CacheException(message: 'Failed to load playlists: $e');
    }
  }

  @override
  Future<Playlist?> getPlaylistById(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    return _fromMap(Map<String, dynamic>.from(data));
  }

  @override
  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final now = DateTime.now();
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(playlist.id, _toMap(playlist));
    return playlist;
  }

  @override
  Future<Playlist> updatePlaylist(Playlist playlist) async {
    final updated = playlist.copyWith(updatedAt: DateTime.now());
    await _box.put(updated.id, _toMap(updated));
    return updated;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _box.delete(id);
  }

  @override
  Future<Playlist> addTrack(String playlistId, Track track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) throw CacheException(message: 'Playlist not found');
    final updatedTracks = [...playlist.tracks, track];
    return updatePlaylist(playlist.copyWith(tracks: updatedTracks));
  }

  @override
  Future<Playlist> removeTrack(String playlistId, int index) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) throw CacheException(message: 'Playlist not found');
    final updatedTracks = [...playlist.tracks]..removeAt(index);
    return updatePlaylist(playlist.copyWith(tracks: updatedTracks));
  }

  @override
  Future<Playlist> reorderTracks(
      String playlistId, int oldIndex, int newIndex) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) throw CacheException(message: 'Playlist not found');
    final updatedTracks = [...playlist.tracks];
    final track = updatedTracks.removeAt(oldIndex);
    updatedTracks.insert(newIndex, track);
    return updatePlaylist(playlist.copyWith(tracks: updatedTracks));
  }

  Map<String, dynamic> _toMap(Playlist playlist) => {
        'id': playlist.id,
        'name': playlist.name,
        'description': playlist.description,
        'tracks': jsonEncode(playlist.tracks
            .map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'artist': t.artist,
                  'album': t.album,
                  'thumbnailUrl': t.thumbnailUrl,
                  'durationMs': t.duration?.inMilliseconds,
                  'source': t.source.name,
                  'localPath': t.localPath,
                  'youtubeVideoId': t.youtubeVideoId,
                })
            .toList()),
        'coverImagePath': playlist.coverImagePath,
        'createdAt': playlist.createdAt.toIso8601String(),
        'updatedAt': playlist.updatedAt.toIso8601String(),
        'isOffline': playlist.isOffline,
      };

  Playlist _fromMap(Map<String, dynamic> map) {
    final tracksJson = jsonDecode(map['tracks'] as String? ?? '[]') as List;
    final tracks = tracksJson.map((t) {
      final trackMap = Map<String, dynamic>.from(t);
      return Track(
        id: trackMap['id'],
        title: trackMap['title'],
        artist: trackMap['artist'],
        album: trackMap['album'],
        thumbnailUrl: trackMap['thumbnailUrl'],
        duration: trackMap['durationMs'] != null
            ? Duration(milliseconds: trackMap['durationMs'])
            : null,
        source: TrackSource.values.firstWhere(
          (s) => s.name == trackMap['source'],
          orElse: () => TrackSource.youtube,
        ),
        localPath: trackMap['localPath'],
        youtubeVideoId: trackMap['youtubeVideoId'],
      );
    }).toList();

    return Playlist(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      tracks: tracks,
      coverImagePath: map['coverImagePath'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isOffline: map['isOffline'] ?? false,
    );
  }
}

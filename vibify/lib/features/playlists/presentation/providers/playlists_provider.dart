import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/usecases/playlist_usecases.dart';
import '../../../player/domain/entities/track.dart';

class PlaylistsNotifier extends StateNotifier<AsyncValue<List<Playlist>>> {
  final PlaylistUsecases _usecases;

  PlaylistsNotifier(this._usecases) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final playlists = await _usecases.getAll();
      state = AsyncData(playlists);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> createPlaylist(String name, {String? description}) async {
    await _usecases.create(name, description: description);
    await load();
  }

  Future<void> deletePlaylist(String id) async {
    await _usecases.delete(id);
    await load();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await _usecases.addTrack(playlistId, track);
    await load();
  }
}

final playlistsNotifierProvider =
    StateNotifierProvider<PlaylistsNotifier, AsyncValue<List<Playlist>>>((ref) {
  return PlaylistsNotifier(sl<PlaylistUsecases>());
});

final singlePlaylistProvider =
    FutureProvider.family<Playlist?, String>((ref, id) async {
  return sl<PlaylistUsecases>().getById(id);
});

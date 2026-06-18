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

  Future<void> removeTrackFromPlaylist(String playlistId, int index) async {
    await _usecases.removeTrack(playlistId, index);
    await load();
  }
}

final playlistsNotifierProvider =
    StateNotifierProvider<PlaylistsNotifier, AsyncValue<List<Playlist>>>((ref) {
  return PlaylistsNotifier(sl<PlaylistUsecases>());
});

/// Derives from playlistsNotifierProvider so it auto-refreshes on any
/// add / remove / delete operation without a separate network call.
final singlePlaylistProvider =
    Provider.family<AsyncValue<Playlist?>, String>((ref, id) {
  return ref.watch(playlistsNotifierProvider).whenData((playlists) {
    try {
      return playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  });
});

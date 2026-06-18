import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../player/domain/entities/track.dart';
import '../../data/datasources/local_music_datasource.dart';
import '../../domain/repositories/local_music_repository.dart';

class LocalMusicState {
  final List<Track> tracks;
  final List<LocalAlbum> albums;
  final List<LocalArtist> artists;
  final List<String> folders;
  final bool isLoading;
  final bool permissionDenied;
  final String? error;

  const LocalMusicState({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.folders = const [],
    this.isLoading = false,
    this.permissionDenied = false,
    this.error,
  });

  LocalMusicState copyWith({
    List<Track>? tracks,
    List<LocalAlbum>? albums,
    List<LocalArtist>? artists,
    List<String>? folders,
    bool? isLoading,
    bool? permissionDenied,
    String? error,
  }) =>
      LocalMusicState(
        tracks: tracks ?? this.tracks,
        albums: albums ?? this.albums,
        artists: artists ?? this.artists,
        folders: folders ?? this.folders,
        isLoading: isLoading ?? this.isLoading,
        permissionDenied: permissionDenied ?? this.permissionDenied,
        error: error,
      );
}

class LocalMusicNotifier extends StateNotifier<LocalMusicState> {
  final LocalMusicRepository _repository;

  LocalMusicNotifier(this._repository) : super(const LocalMusicState());

  Future<void> init() async {
    final granted = await _repository.requestPermission();
    if (!granted) {
      state = state.copyWith(permissionDenied: true);
      return;
    }
    await _load();
  }

  Future<void> requestPermission() async {
    final granted = await _repository.requestPermission();
    if (granted) {
      state = state.copyWith(permissionDenied: false);
      await _load();
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repository.getAllTracks(),
        _repository.getAllAlbums(),
        _repository.getAllArtists(),
        _repository.getAllFolders(),
      ]);

      state = state.copyWith(
        tracks: results[0] as List<Track>,
        albums: results[1] as List<LocalAlbum>,
        artists: results[2] as List<LocalArtist>,
        folders: results[3] as List<String>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final localMusicNotifierProvider =
    StateNotifierProvider<LocalMusicNotifier, LocalMusicState>((ref) {
  return LocalMusicNotifier(sl<LocalMusicRepository>());
});

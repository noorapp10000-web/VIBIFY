import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../player/domain/entities/track.dart';
import '../../../playlists/domain/entities/playlist.dart';
import '../../../playlists/domain/usecases/playlist_usecases.dart';

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  return sl<PlaylistUsecases>().getAll();
});

final libraryFavoritesProvider = FutureProvider<List<Track>>((ref) async {
  final box = Hive.box(AppConstants.favoritesBox);
  final tracks = <Track>[];
  for (final key in box.keys) {
    final data = box.get(key);
    if (data != null) {
      tracks.add(_trackFromMap(Map<String, dynamic>.from(data)));
    }
  }
  return tracks;
});

final libraryHistoryProvider = FutureProvider<List<Track>>((ref) async {
  final box = Hive.box(AppConstants.historyBox);
  final tracks = <Track>[];
  for (final key in box.keys.take(50)) {
    final data = box.get(key);
    if (data != null) {
      tracks.add(_trackFromMap(Map<String, dynamic>.from(data)));
    }
  }
  return tracks;
});

Track _trackFromMap(Map<String, dynamic> m) => Track(
      id: m['id'] ?? '',
      title: m['title'] ?? 'Unknown',
      artist: m['artist'] ?? 'Unknown',
      album: m['album'],
      thumbnailUrl: m['thumbnailUrl'],
      duration: m['durationMs'] != null
          ? Duration(milliseconds: m['durationMs'])
          : null,
      source: TrackSource.values.firstWhere(
        (s) => s.name == m['source'],
        orElse: () => TrackSource.youtube,
      ),
      localPath: m['localPath'],
      youtubeVideoId: m['youtubeVideoId'],
    );

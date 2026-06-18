import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../player/domain/entities/track.dart';

// Counter incremented whenever favorites change — causes libraryFavoritesProvider to reload
final favoritesVersionProvider = StateProvider<int>((ref) => 0);

final libraryFavoritesProvider = FutureProvider<List<Track>>((ref) async {
  ref.watch(favoritesVersionProvider);
  final box = Hive.box(AppConstants.favoritesBox);
  final tracks = <Track>[];
  for (final key in box.keys) {
    final data = box.get(key);
    if (data != null) {
      tracks.add(_trackFromMap(Map<String, dynamic>.from(data as Map)));
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
      tracks.add(_trackFromMap(Map<String, dynamic>.from(data as Map)));
    }
  }
  return tracks;
});

Track _trackFromMap(Map<String, dynamic> m) => Track(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? 'Unknown',
      artist: m['artist'] as String? ?? 'Unknown',
      album: m['album'] as String?,
      thumbnailUrl: m['thumbnailUrl'] as String?,
      duration: m['durationMs'] != null
          ? Duration(milliseconds: m['durationMs'] as int)
          : null,
      source: TrackSource.values.firstWhere(
        (s) => s.name == m['source'],
        orElse: () => TrackSource.youtube,
      ),
      localPath: m['localPath'] as String?,
      youtubeVideoId: m['youtubeVideoId'] as String?,
    );

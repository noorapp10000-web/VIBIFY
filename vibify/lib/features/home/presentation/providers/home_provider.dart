import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../player/domain/entities/track.dart';

final recentlyPlayedProvider = FutureProvider<List<Track>>((ref) async {
  final box = Hive.box(AppConstants.historyBox);
  final tracks = <Track>[];
  for (final key in box.keys.take(20)) {
    final data = box.get(key);
    if (data != null) {
      final m = Map<String, dynamic>.from(data);
      tracks.add(_trackFromMap(m));
    }
  }
  return tracks;
});

final favoritesProvider = FutureProvider<List<Track>>((ref) async {
  final box = Hive.box(AppConstants.favoritesBox);
  final tracks = <Track>[];
  for (final key in box.keys) {
    final data = box.get(key);
    if (data != null) {
      final m = Map<String, dynamic>.from(data);
      tracks.add(_trackFromMap(m));
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

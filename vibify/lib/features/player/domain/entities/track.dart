import 'package:equatable/equatable.dart';

enum TrackSource { youtube, local, download }

class Track extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final Duration? duration;
  final TrackSource source;
  final String? localPath;
  final String? youtubeVideoId;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayed;
  final DateTime? addedAt;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    this.duration,
    required this.source,
    this.localPath,
    this.youtubeVideoId,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayed,
    this.addedAt,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    Duration? duration,
    TrackSource? source,
    String? localPath,
    String? youtubeVideoId,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    DateTime? addedAt,
  }) =>
      Track(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        duration: duration ?? this.duration,
        source: source ?? this.source,
        localPath: localPath ?? this.localPath,
        youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
        isFavorite: isFavorite ?? this.isFavorite,
        playCount: playCount ?? this.playCount,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        addedAt: addedAt ?? this.addedAt,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        thumbnailUrl,
        duration,
        source,
        localPath,
        youtubeVideoId,
        isFavorite,
        playCount,
      ];
}

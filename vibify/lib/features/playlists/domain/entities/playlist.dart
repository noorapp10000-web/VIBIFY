import 'package:equatable/equatable.dart';

import '../../../player/domain/entities/track.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String? description;
  final List<Track> tracks;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOffline;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.tracks = const [],
    this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.isOffline = false,
  });

  int get trackCount => tracks.length;

  Duration get totalDuration => tracks.fold(
        Duration.zero,
        (total, track) => total + (track.duration ?? Duration.zero),
      );

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<Track>? tracks,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOffline,
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        tracks: tracks ?? this.tracks,
        coverImagePath: coverImagePath ?? this.coverImagePath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isOffline: isOffline ?? this.isOffline,
      );

  @override
  List<Object?> get props => [id, name, tracks, updatedAt];
}

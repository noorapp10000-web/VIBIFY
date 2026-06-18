import 'package:equatable/equatable.dart';

import '../../player/domain/entities/track.dart';

class SearchResult extends Equatable {
  final List<Track> tracks;
  final List<SearchArtist> artists;
  final List<SearchPlaylist> playlists;
  final String query;

  const SearchResult({
    required this.tracks,
    required this.artists,
    required this.playlists,
    required this.query,
  });

  bool get isEmpty =>
      tracks.isEmpty && artists.isEmpty && playlists.isEmpty;

  @override
  List<Object?> get props => [tracks, artists, playlists, query];
}

class SearchArtist extends Equatable {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final int? subscriberCount;

  const SearchArtist({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.subscriberCount,
  });

  @override
  List<Object?> get props => [id, name];
}

class SearchPlaylist extends Equatable {
  final String id;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final int? trackCount;

  const SearchPlaylist({
    required this.id,
    required this.title,
    this.author,
    this.thumbnailUrl,
    this.trackCount,
  });

  @override
  List<Object?> get props => [id, title];
}

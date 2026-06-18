import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../player/domain/entities/track.dart';
import '../../domain/entities/search_result.dart';

abstract class YoutubeDatasource {
  Future<SearchResult> search(String query, {int limit = 20});
  Future<Track> getTrackDetails(String videoId);
  Future<List<Track>> getPlaylistTracks(String playlistId);
}

class YoutubeDatasourceImpl implements YoutubeDatasource {
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  Future<SearchResult> search(String query, {int limit = 20}) async {
    try {
      final searchList = await _yt.search.search(query);
      final tracks = <Track>[];
      final artists = <SearchArtist>[];
      final playlists = <SearchPlaylist>[];

      for (final result in searchList.take(limit)) {
        if (result is SearchVideo) {
          tracks.add(_videoToTrack(result));
        } else if (result is SearchChannel) {
          artists.add(SearchArtist(
            id: result.id.value,
            name: result.name,
            thumbnailUrl: result.thumbnails.highResUrl,
          ));
        } else if (result is SearchPlaylist) {
          playlists.add(SearchPlaylist(
            id: result.id.value,
            title: result.title,
            thumbnailUrl: result.thumbnails.firstOrNull?.url.toString(),
          ));
        }
      }

      return SearchResult(
        tracks: tracks,
        artists: artists,
        playlists: playlists,
        query: query,
      );
    } catch (e) {
      throw StreamException(message: 'Search failed: $e');
    }
  }

  @override
  Future<Track> getTrackDetails(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return Track(
        id: videoId,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        source: TrackSource.youtube,
        youtubeVideoId: videoId,
        addedAt: DateTime.now(),
      );
    } catch (e) {
      throw StreamException(message: 'Failed to get track details: $e');
    }
  }

  @override
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    try {
      final playlist = await _yt.playlists.getVideos(playlistId);
      final tracks = <Track>[];
      await for (final video in playlist) {
        tracks.add(Track(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          duration: video.duration,
          thumbnailUrl: video.thumbnails.highResUrl,
          source: TrackSource.youtube,
          youtubeVideoId: video.id.value,
          addedAt: DateTime.now(),
        ));
      }
      return tracks;
    } catch (e) {
      throw StreamException(message: 'Failed to get playlist tracks: $e');
    }
  }

  Track _videoToTrack(SearchVideo video) => Track(
        id: video.id.value,
        title: video.title,
        artist: video.channelName ?? 'Unknown',
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        source: TrackSource.youtube,
        youtubeVideoId: video.id.value,
        addedAt: DateTime.now(),
      );
}

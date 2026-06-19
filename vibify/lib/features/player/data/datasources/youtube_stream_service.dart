import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeStreamService {
  Future<String?> getAudioUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final audioUrl = streamInfo.url.toString();
      debugPrint('[YoutubeStreamService] ✓ Got audio URL for $videoId');
      return audioUrl;
    } catch (e) {
      debugPrint('[YoutubeStreamService] ✗ Failed for $videoId: $e');
      return null;
    } finally {
      yt.close();
    }
  }
}

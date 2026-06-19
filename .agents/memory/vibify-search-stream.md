---
name: Vibify Search & Stream Engine
description: Search uses Cloudflare Worker API via http package; Stream uses youtube_explode_dart only — no InnerTube, Piped, or WebView fallbacks.
---

## Search Engine
- Package: `http: ^1.2.2`
- Endpoint: `https://yt-audio-api.noor-app-100.workers.dev/api/search?q={query}`
- File: `lib/features/search/data/datasources/youtube_datasource.dart`
- JSON response shape: flexible — handles list or map with `results`/`items`/`videos` keys
- Fields extracted: `videoId`, `title`, `thumbnail`, `author`/`channelTitle`/`channel`, `duration` (string or int seconds)

## Stream Engine
- Package: `youtube_explode_dart: ^2.2.1`
- Service class: `lib/features/player/data/datasources/youtube_stream_service.dart`
- Registered in DI as `YoutubeStreamService` singleton
- Used by both `VibifyAudioHandler` (playback) and `DownloadDatasourceImpl` (download)

**Why:** InnerTube ANDROID + Piped were unreliable on server/datacenter IPs; WebView iframe approach was brittle. `youtube_explode_dart` provides stable extraction from real device IPs.

**How to apply:** Any place that needs a YouTube audio URL must go through `YoutubeStreamService.getAudioUrl(videoId)`. Never call InnerTube or Piped APIs directly. The Cloudflare Worker is search-only; never use it for stream extraction.

## Removed
- `webview_flutter` package (removed from pubspec)
- `youtube_iframe_extractor.dart` (stubbed)
- `StreamResolution` class, `resolveYoutubeStream`, `_getStreamViaPiped`, `_getStreamViaInnerTube` from audio_handler.dart
- `getPipedStreamUrl` from datasource/repository/domain layers
- Iframe extraction UI from `player_page.dart`

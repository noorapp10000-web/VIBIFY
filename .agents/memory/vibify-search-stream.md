---
name: Vibify Search & Stream Engine
description: Search uses Cloudflare Worker API via http package; Stream uses youtube_explode_dart v3.1.0 with AudioSource.uri() — no custom proxy, no YoutubeHttpClient.
---

## Search Engine
- Package: `http: ^1.2.2`
- Endpoint: `https://yt-audio-api.noor-app-100.workers.dev/api/search?q={query}`
- File: `lib/features/search/data/datasources/youtube_datasource.dart`
- JSON response shape: flexible — handles list or map with `results`/`items`/`videos` keys
- Fields extracted: `videoId`, `title`, `thumbnail`, `author`/`channelTitle`/`channel`, `duration` (string or int seconds)

## Stream Engine (youtube_explode_dart ^3.1.0)
- **Key rule:** Use `AudioSource.uri(info.url)` directly — do NOT use `StreamAudioSource` + `YoutubeHttpClient`.
- `getManifest(videoId)` → pick best audio via `_pickBestAudio()` (prefers AAC/MP4, falls back to highest bitrate).
- ExoPlayer (inside just_audio) handles all HTTP range requests natively. The signed `googlevideo.com` URL needs no extra headers.
- `YoutubeExplode` instance is created fresh per track and closed immediately after the URL is obtained (URL is self-contained).
- `YoutubeStreamService.downloadToFile()` uses `yt.videos.streamsClient.get(info)` for streaming to disk (download only).

**Why:** In v3.1.0, `YoutubeHttpClient.send(http.Request)` does NOT add YouTube-specific headers to externally constructed requests — so the old `StreamAudioSource` range-request proxy silently fails. `AudioSource.uri()` delegates HTTP to ExoPlayer which handles ranges natively without extra headers.

**How to apply:** Any playback call goes through `VibifyAudioHandler._playYoutubeTrack()`. Downloads go through `YoutubeStreamService.downloadToFile()`. Never use `StreamAudioSource`, `YoutubeHttpClient`, or manual range requests for playback.

## Removed / Do Not Re-add
- `_YoutubeStreamAudioSource` (StreamAudioSource subclass with manual YoutubeHttpClient range requests) — broken in v3.1.0
- `AudioStreamResult` class (was used to pass stream+yt instance — no longer needed)
- `webview_flutter` package
- `youtube_iframe_extractor.dart` (stubbed)
- InnerTube / Piped direct calls

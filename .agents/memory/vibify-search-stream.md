---
name: Vibify Search & Stream Engine
description: Stream resolution: InnerTube ANDROID direct (primary) → youtube_explode_dart (fallback). audio_handler uses YoutubeStreamService only — no direct yt-explode calls.
---

## Search Engine
- Package: `http: ^1.2.2`
- Endpoint: `https://yt-audio-api.noor-app-100.workers.dev/api/search?q={query}`
- File: `lib/features/search/data/datasources/youtube_datasource.dart`

## Stream Engine — Architecture

### Flow
```
_playYoutubeTrack(videoId)
  → YoutubeStreamService.resolveStream(videoId)
      → Strategy 1: InnerTube ANDROID direct  ← PRIMARY
      → Strategy 2: youtube_explode_dart        ← FALLBACK
  → AudioSource.uri(url, headers: {User-Agent: kYoutubeAndroidUserAgent})
  → ExoPlayer handles all HTTP + range requests natively
```

### Why InnerTube ANDROID is primary
- ANDROID client returns **unencrypted** URLs — no JS cipher decryption needed.
- JS cipher in youtube_explode_dart breaks whenever YouTube updates their JS player.
- Real Android device IPs are not blocked by YouTube CDN.
- `User-Agent` header must be passed to `AudioSource.uri()` so the CDN URL (signed for Android UA) isn't rejected by ExoPlayer's HTTP client.

### Key constants
- `kYoutubeAndroidUserAgent` = `'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip'`
- InnerTube API key: `AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w`
- InnerTube endpoint: `POST https://www.youtube.com/youtubei/v1/player?prettyPrint=false`

### DI wiring
- `YoutubeStreamService` registered first as lazy singleton.
- `VibifyAudioHandler.createAndInit(sl<YoutubeStreamService>())` — receives service via constructor.
- Downloads use `YoutubeStreamService.downloadToFile()` (yt-explode stream, unaffected by playback change).

## Do NOT re-add
- Direct `YoutubeExplode()` calls inside `audio_handler.dart`
- `StreamAudioSource` + `YoutubeHttpClient` for range requests (broken in v3.x)
- `getAudioUrl()` method (replaced by `resolveStream()` returning `ResolvedStream`)

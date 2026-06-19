---
name: Vibify Search & Stream Engine
description: YouTube playback via InnerTube ANDROID + just_audio. No IFrame/WebView. Custom Flutter UI only. Downloads via same InnerTube URL + Dio.
---

## Architecture (current — final)

### YouTube Playback
- **Engine**: InnerTube ANDROID API → direct URL → `just_audio` (ExoPlayer)
- **Handler**: `VibifyAudioHandler._playYoutube(videoId)`
  1. Calls `YoutubeStreamService.resolveStream(videoId)` — InnerTube primary, yt-explode fallback
  2. `_player.setAudioSource(AudioSource.uri(url, headers: {User-Agent: Android}))` 
  3. `_player.play()`
- **UI**: Full custom Flutter gradient layout — no YouTube branding, no WebView, no IFrame

### Why NOT IFrame (lessons learned)
- Error 153 = video not embeddable → IFrame shows YouTube error UI we can't hide
- YouTube controls bleed through even with `controls:0`
- Some videos blocked from embedding entirely
- InnerTube ANDROID from real device IP = YouTube thinks it's the official Android app → no blocks

### Local File Playback
- `just_audio` → `setFilePath(localPath)` + `play()`

### Downloads
- **Engine**: `YoutubeStreamService.downloadToFile()` → InnerTube URL + Dio (primary), yt-explode (fallback)
- **Progress**: YouTube CDN returns chunked responses with `Content-Length: -1`
  - When `total = -1`: show indeterminate bar + MB downloaded (not %)
  - When `total > 0`: show normal % progress bar
- `DownloadItem.fileSizeBytes` is nullable — null = chunked/unknown size

## Key Files
- `audio_handler.dart` — `_playYoutube()` resolves InnerTube → just_audio
- `youtube_stream_service.dart` — `resolveStream()` + `downloadToFile()` 
- `injection.dart` — `VibifyAudioHandler.createAndInit(sl<YoutubeStreamService>())`
- `download_datasource.dart` — handles `total = -1` gracefully
- `downloads_page.dart` — indeterminate bar when fileSizeBytes null

## Deleted Files
- `youtube_iframe_player.dart` — removed (IFrame approach abandoned)
- `youtube_iframe_extractor.dart` — removed (unused)

## DO NOT
- Re-add IFrame/WebView for playback — fundamentally broken for non-embeddable videos
- Use `?.['key']` syntax in Dart — must be `?['key']` (no dot before bracket)
- Use `Options(receiveTimeout:)` from dio in conflicting context — use `BaseOptions` on `Dio()` instance
- Import `dio` without `as dio_lib` alias alongside `youtube_explode_dart`

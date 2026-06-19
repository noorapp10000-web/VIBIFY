---
name: Vibify Search & Stream Engine
description: YouTube playback via IFrame API (WebView). audio_handler manages local files + queue metadata only. YoutubeStreamService kept for downloads.
---

## Architecture (current)

### YouTube Playback
- **Engine**: `YoutubeIframePlayer` widget (WebView + YouTube IFrame API)
- **File**: `lib/features/player/presentation/widgets/youtube_iframe_player.dart`
- **PlayerPage**: when `track.source == TrackSource.youtube`, renders full-screen Stack with IFrame player + header overlay
- **audio_handler**: for YouTube tracks → `_player.stop()` + idle state only (no audio_player involvement)
- **No encryption issues**: YouTube handles URL resolution internally via IFrame API

### Local File Playback
- **Engine**: `just_audio` via `VibifyAudioHandler`
- Works unchanged — `setFilePath` + `play()`

### Downloads
- **Engine**: `YoutubeStreamService.downloadToFile()` (youtube_explode_dart stream)
- `YoutubeStreamService` registered in DI, passed to `DownloadDatasourceImpl`

## IFrame Player — Key Details

### Pointer Events / Skip Ad Trick
- `WebViewWidget` at bottom of Stack — receives all unhandled taps
- `GestureDetector(behavior: HitTestBehavior.translucent)` layer → shows controls AND passes event to WebView
- Decorative widgets (gradient, LIVE badge, buffering ring) wrapped in `IgnorePointer`
- Interactive controls (play/pause, slider) wrapped in `IgnorePointer(ignoring: !_controlsVisible)`
- Empty areas → no Flutter widget → tap goes directly to WebView → Skip Ad works

### JS ↔ Flutter Communication
- Flutter channel name: `Vibify`
- JS → Flutter: `Vibify.postMessage(JSON.stringify({type, ...}))` 
  - types: `ready`, `state`, `tick`
- Flutter → JS: `_wvc.runJavaScript('play()|pause()|seek(s)|loadVideo(id)')`

### Live Stream Detection
- `duration == 0` → `_isLive = true` → hides seek bar, shows red LIVE badge

### Track Change (queue skip)
- `didUpdateWidget` detects `old.videoId != widget.videoId`
- Calls `loadVideo(newId)` via JS — no WebView rebuild, no flash

### Player vars (hidden chrome)
- `controls:0, rel:0, modestbranding:1, disablekb:1, fs:0, iv_load_policy:3`

## Do NOT re-add
- `_YoutubeStreamAudioSource` (StreamAudioSource + YoutubeHttpClient range requests)
- Direct `YoutubeExplode()` calls in `audio_handler.dart`
- `getAudioUrl()` / `resolveStream()` calls in the playback path

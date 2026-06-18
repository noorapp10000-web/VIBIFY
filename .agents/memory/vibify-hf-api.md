---
name: Vibify HuggingFace API
description: Architecture of Vibify music API server and Flutter client strategy.
---

## Architecture
- **Search**: InnerTube WEB client (`youtubei/v1/search`) directly from Flutter — ~0.7s, not blocked on Android.
- **Stream URLs**: InnerTube ANDROID client (`youtubei/v1/player`) directly from Flutter — returns unencrypted URLs, no JS cipher needed.
- **HF Server** (`Seifooooooo-vibify-api.hf.space`): fallback only for stream URLs. HuggingFace datacenter IPs are blocked/timeout-limited by YouTube (both search and stream), so client-side is primary.

**Why:** YouTube blocks datacenter IP ranges (HuggingFace, Render, etc.) for both search and stream. Android device IPs are not blocked. InnerTube ANDROID client bypasses bot-detection that killed `youtube_explode_dart`.

## InnerTube Keys
- WEB search: `AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8`
- ANDROID player: `AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w` (clientVersion: `19.09.37`)

## HF Commit API
- `{"summary":"...","files":[{"path":"...","content":"raw-text"}]}`
- Raw text in `content` (NOT base64)
- `colorTo` in README must be: red/yellow/green/blue/indigo/purple/pink/gray

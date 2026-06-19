import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─── YouTube player state codes (mirrors IFrame API) ─────────────────────────
enum _YTState { unstarted, ended, playing, paused, buffering, cued }

const _kStateMap = {
  -1: _YTState.unstarted,
  0: _YTState.ended,
  1: _YTState.playing,
  2: _YTState.paused,
  3: _YTState.buffering,
  5: _YTState.cued,
};

// ─── Public Widget ────────────────────────────────────────────────────────────

/// Full-screen YouTube IFrame player with a fully custom UI overlay.
///
/// Architecture:
///   Layer 1 (bottom) — WebViewWidget running the YouTube IFrame API.
///     controls:0 hides all native YouTube chrome.
///   Layer 2 — translucent GestureDetector (passes events down to WebView).
///     Empty areas forward pointer events → "Skip Ad" button stays clickable.
///   Layer 3 — IgnorePointer decorations (gradient, LIVE badge, buffering ring).
///   Layer 4 — Interactive controls (Play/Pause, Slider, Skip buttons).
///     Only these absorb pointer events.
class YoutubeIframePlayer extends StatefulWidget {
  final String videoId;

  /// Called when the video ends naturally.
  final VoidCallback? onEnded;

  /// Called when the user taps the skip-next button.
  final VoidCallback? onSkipNext;

  /// Called when the user taps the skip-previous button.
  final VoidCallback? onSkipPrevious;

  final bool hasNext;
  final bool hasPrevious;

  const YoutubeIframePlayer({
    super.key,
    required this.videoId,
    this.onEnded,
    this.onSkipNext,
    this.onSkipPrevious,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  @override
  State<YoutubeIframePlayer> createState() => _YoutubeIframePlayerState();
}

class _YoutubeIframePlayerState extends State<YoutubeIframePlayer> {
  late final WebViewController _wvc;

  _YTState _ytState = _YTState.unstarted;
  double _current = 0;
  double _duration = 0;
  bool _isLive = false;
  bool _controlsVisible = true;
  bool _seeking = false;
  Timer? _hideTimer;

  bool get _isPlaying => _ytState == _YTState.playing;
  bool get _isBuffering =>
      _ytState == _YTState.buffering || _ytState == _YTState.unstarted;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _buildController(widget.videoId);
  }

  @override
  void didUpdateWidget(YoutubeIframePlayer old) {
    super.didUpdateWidget(old);
    // When the parent changes the videoId (queue skip), reload without
    // rebuilding the entire WebView — avoids a full white-flash reload.
    if (old.videoId != widget.videoId) {
      _wvc.runJavaScript("loadVideo('${widget.videoId}')");
      setState(() {
        _ytState = _YTState.unstarted;
        _current = 0;
        _duration = 0;
        _isLive = false;
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  // ── WebView setup ──────────────────────────────────────────────────────────

  void _buildController(String videoId) {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('Vibify', onMessageReceived: _onMessage)
      ..loadHtmlString(_buildHtml(videoId));
  }

  void _onMessage(JavaScriptMessage msg) {
    if (!mounted) return;
    try {
      final d = jsonDecode(msg.message) as Map<String, dynamic>;
      switch (d['type'] as String?) {
        case 'ready':
          final dur = (d['duration'] as num?)?.toDouble() ?? 0.0;
          setState(() {
            _duration = dur;
            _isLive = dur == 0;
          });

        case 'state':
          final code = d['code'] as int? ?? -1;
          final s = _kStateMap[code];
          if (s == null) return;
          setState(() => _ytState = s);
          if (s == _YTState.playing) _scheduleHide();
          if (s == _YTState.ended) widget.onEnded?.call();

        case 'tick':
          if (_seeking) return;
          setState(() {
            _current = (d['t'] as num?)?.toDouble() ?? _current;
            final dur = (d['d'] as num?)?.toDouble() ?? _duration;
            _duration = dur;
            _isLive = dur == 0;
          });
      }
    } catch (_) {}
  }

  // ── Controls logic ─────────────────────────────────────────────────────────

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    if (_isPlaying) _scheduleHide();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _wvc.runJavaScript('pause()');
    } else {
      _wvc.runJavaScript('play()');
    }
    _showControls();
  }

  void _onSeekStart(double _) => setState(() => _seeking = true);

  void _onSeekUpdate(double v) => setState(() => _current = v);

  void _onSeekEnd(double v) {
    _wvc.runJavaScript('seek($v)');
    setState(() {
      _current = v;
      _seeking = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: YouTube IFrame ──────────────────────────────────────
        // Receives ALL pointer events not intercepted by layers above.
        // This ensures "Skip Ad" button (rendered inside the WebView)
        // remains tappable when the custom UI has no widget there.
        WebViewWidget(controller: _wvc),

        // ── Layer 2: Tap-to-toggle-controls ─────────────────────────────
        // HitTestBehavior.translucent: the GestureDetector handles the
        // tap AND forwards the raw pointer event down to the WebView.
        // This is the key trick for Skip Ad passthrough.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _showControls,
          child: const SizedBox.expand(),
        ),

        // ── Layer 3: Bottom gradient (decorative — IgnorePointer) ────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
        ),

        // ── Layer 3b: Top gradient (decorative — IgnorePointer) ──────────
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // ── Layer 3c: Buffering ring (decorative — IgnorePointer) ────────
        if (_isBuffering)
          const Center(
            child: IgnorePointer(
              child: SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),

        // ── Layer 3d: LIVE badge (decorative — IgnorePointer) ────────────
        if (_isLive)
          const Positioned(
            top: 16,
            left: 16,
            child: IgnorePointer(child: _LiveBadge()),
          ),

        // ── Layer 4: Interactive custom controls ─────────────────────────
        // Wrapped in AnimatedOpacity so controls can fade in/out.
        // Individual widgets inside are interactive (no IgnorePointer).
        AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            // When controls are invisible, ignore all events so the
            // WebView (Skip Ad) stays fully responsive.
            ignoring: !_controlsVisible,
            child: _buildControlsLayer(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Center row: skip-prev • play/pause • skip-next ───────────────
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleButton(
                icon: Icons.skip_previous_rounded,
                iconSize: 30,
                diameter: 52,
                opacity: widget.hasPrevious ? 1.0 : 0.35,
                onTap: widget.hasPrevious ? widget.onSkipPrevious : null,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                iconSize: 42,
                diameter: 72,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.skip_next_rounded,
                iconSize: 30,
                diameter: 52,
                opacity: widget.hasNext ? 1.0 : 0.35,
                onTap: widget.hasNext ? widget.onSkipNext : null,
              ),
            ],
          ),
        ),

        // ── Bottom: seek bar + timestamps (hidden for live streams) ──────
        if (!_isLive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSeekBar(),
          ),
      ],
    );
  }

  Widget _buildSeekBar() {
    final maxVal = _duration > 0 ? _duration : 1.0;
    final curVal = _current.clamp(0.0, maxVal);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timestamps
          Row(
            children: [
              Text(
                _formatTime(_current),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              Text(
                _formatTime(_duration),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Custom-styled seek slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: const Color(0xFFD6B48A),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: curVal,
              min: 0,
              max: maxVal,
              onChangeStart: _duration > 0 ? _onSeekStart : null,
              onChanged: _duration > 0 ? _onSeekUpdate : null,
              onChangeEnd: _duration > 0 ? _onSeekEnd : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── HTML ───────────────────────────────────────────────────────────────────

  /// Generates the HTML page that bootstraps the YouTube IFrame API.
  ///
  /// Player vars used:
  ///   controls:0        – hide all native YouTube chrome
  ///   rel:0             – no related videos at end
  ///   modestbranding:1  – remove YouTube logo from control bar
  ///   disablekb:1       – disable keyboard shortcuts inside iframe
  ///   fs:0              – disable native fullscreen button
  ///   playsinline:1     – prevent iOS from going fullscreen automatically
  ///   iv_load_policy:3  – hide video annotations
  ///   cc_load_policy:0  – disable closed captions by default
  static String _buildHtml(String videoId) => '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport"
      content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%; height: 100%;
    background: #000; overflow: hidden;
  }
  #p {
    position: absolute;
    top: 0; left: 0;
    width: 100%; height: 100%;
  }
</style>
</head>
<body>
<div id="p"></div>
<script>
(function() {
  // Inject IFrame API script
  var tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  document.head.appendChild(tag);

  var yt, ticker;

  // Called automatically by the IFrame API once loaded
  window.onYouTubeIframeAPIReady = function() {
    yt = new YT.Player('p', {
      videoId: '$videoId',
      playerVars: {
        autoplay:        1,
        controls:        0,
        rel:             0,
        modestbranding:  1,
        disablekb:       1,
        fs:              0,
        playsinline:     1,
        iv_load_policy:  3,
        cc_load_policy:  0,
        showinfo:        0
      },
      events: {
        onReady: function(e) {
          e.target.playVideo();
          Vibify.postMessage(JSON.stringify({
            type: 'ready',
            duration: yt.getDuration()
          }));
          // Start 500 ms position ticker
          ticker = setInterval(function() {
            if (!yt || !yt.getCurrentTime) return;
            Vibify.postMessage(JSON.stringify({
              type: 'tick',
              t: yt.getCurrentTime(),
              d: yt.getDuration()
            }));
          }, 500);
        },
        onStateChange: function(e) {
          Vibify.postMessage(JSON.stringify({
            type: 'state',
            code: e.data
          }));
        }
      }
    });
  };

  // Commands called from Flutter via runJavaScript()
  window.play       = function()  { yt && yt.playVideo(); };
  window.pause      = function()  { yt && yt.pauseVideo(); };
  window.seek       = function(s) { yt && yt.seekTo(s, true); };
  window.loadVideo  = function(id){
    if (yt) {
      yt.loadVideoById(id);
    }
  };
})();
</script>
</body>
</html>''';
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double diameter;
  final VoidCallback? onTap;
  final double opacity;

  const _CircleButton({
    required this.icon,
    required this.iconSize,
    required this.diameter,
    this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinking dot
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

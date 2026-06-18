import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Runs a hidden WebView that loads the YouTube embed page,
/// intercepts network requests, and captures the audio /videoplayback URL.
class YoutubeIframeExtractor {
  static Future<String?> extractStreamUrl(
    String videoId, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    // Must run on the main thread (UI)
    final completer = Completer<String?>();

    await _runExtractor(videoId, completer, timeout);
    return completer.future;
  }

  static Future<void> _runExtractor(
    String videoId,
    Completer<String?> completer,
    Duration timeout,
  ) async {
    final controller = WebViewController();

    Timer? timer;

    void complete(String? url) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(url);
    }

    timer = Timer(timeout, () => complete(null));

    // JavaScript that intercepts fetch/XHR calls and postMessages the audio URL
    const interceptJs = '''
(function() {
  const origFetch = window.fetch;
  window.fetch = function(...args) {
    const url = args[0]?.url ?? (typeof args[0] === 'string' ? args[0] : '');
    if (url.includes('googlevideo.com') && (url.includes('mime=audio') || url.includes('itag=140') || url.includes('itag=251'))) {
      window.flutter_inappwebview?.callHandler?.('streamUrl', url);
      if (window.VibifyStream) window.VibifyStream.postMessage(url);
    }
    return origFetch.apply(this, args);
  };

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (typeof url === 'string' && url.includes('googlevideo.com')) {
      if (window.VibifyStream) window.VibifyStream.postMessage(url);
    }
    return origOpen.apply(this, arguments);
  };
})();
''';

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    await controller.addJavaScriptChannel(
      'VibifyStream',
      onMessageReceived: (msg) {
        final url = msg.message;
        if (url.contains('googlevideo.com') && !completer.isCompleted) {
          debugPrint('[IframeExtractor] Got stream URL: ${url.substring(0, 80)}');
          complete(url);
        }
      },
    );

    await controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async {
        await controller.runJavaScript(interceptJs);
        // Trigger playback via JS to force stream URL fetch
        await controller.runJavaScript('''
          try {
            var iframe = document.querySelector("iframe");
            if (!iframe) {
              document.body.innerHTML = '<iframe id="ytplayer" src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&controls=0&mute=0&enablejsapi=1" allow="autoplay" width="1" height="1"></iframe>';
            }
          } catch(e) {}
        ''');
      },
    ));

    final embedUrl =
        'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&controls=0&mute=0&enablejsapi=1';

    await controller.loadRequest(Uri.parse(embedUrl));
  }
}

/// A tiny invisible widget that hosts the WebView extractor.
/// Add this to the widget tree temporarily during stream extraction.
class YoutubeStreamExtractorWidget extends StatefulWidget {
  final String videoId;
  final void Function(String url) onStreamFound;
  final VoidCallback onFailed;

  const YoutubeStreamExtractorWidget({
    super.key,
    required this.videoId,
    required this.onStreamFound,
    required this.onFailed,
  });

  @override
  State<YoutubeStreamExtractorWidget> createState() =>
      _YoutubeStreamExtractorWidgetState();
}

class _YoutubeStreamExtractorWidgetState
    extends State<YoutubeStreamExtractorWidget> {
  late final WebViewController _controller;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 25), _fail);
    _setup();
  }

  void _succeed(String url) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onStreamFound(url);
  }

  void _fail() {
    if (_done) return;
    _done = true;
    widget.onFailed();
  }

  Future<void> _setup() async {
    _controller = WebViewController();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.addJavaScriptChannel(
      'VibifyStream',
      onMessageReceived: (msg) {
        final url = msg.message;
        if (url.contains('googlevideo.com')) _succeed(url);
      },
    );
    await _controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) async {
        const js = '''
(function() {
  const orig = window.fetch;
  window.fetch = function(...a) {
    const u = (typeof a[0] === "string" ? a[0] : a[0]?.url) ?? "";
    if (u.includes("googlevideo.com")) { try { VibifyStream.postMessage(u); } catch(e){} }
    return orig.apply(this, a);
  };
  const origXHR = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(m, u) {
    if (typeof u === "string" && u.includes("googlevideo.com")) { try { VibifyStream.postMessage(u); } catch(e){} }
    return origXHR.apply(this, arguments);
  };
})();
''';
        await _controller.runJavaScript(js);
      },
    ));

    final url =
        'https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&controls=0&enablejsapi=1';
    await _controller.loadRequest(Uri.parse(url));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}

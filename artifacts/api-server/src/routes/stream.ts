import { Router } from "express";

const router = Router();

const PLAYER_URL = "https://www.youtube.com/youtubei/v1/player";

interface StreamResult {
  url: string;
  mimeType?: string;
  bitrate?: number;
  quality?: string;
  client: string;
}

async function getVisitorDataFromEmbed(videoId: string): Promise<{ visitorData: string; apiKey: string; clientVersion: string }> {
  try {
    const resp = await fetch(`https://www.youtube.com/embed/${videoId}`, {
      signal: AbortSignal.timeout(8000),
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Safari/537.36",
        Accept: "text/html",
        "Referer": "https://www.example.com/",
      },
    });
    const html = await resp.text();
    return {
      apiKey: html.match(/"INNERTUBE_API_KEY":"([^"]+)"/)?.[1] ?? "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8",
      visitorData: html.match(/"visitorData":"([^"]+)"/)?.[1] ?? "",
      clientVersion: html.match(/"INNERTUBE_CONTEXT_CLIENT_VERSION":"([^"]+)"/)?.[1] ?? "2.20260618.01.00",
    };
  } catch {
    return { apiKey: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8", visitorData: "", clientVersion: "2.20260618.01.00" };
  }
}

function extractAudio(data: any): StreamResult | null {
  const sd = data?.streamingData;
  if (!sd) return null;
  const adaptive: any[] = sd.adaptiveFormats ?? [];
  const audio = adaptive
    .filter((f: any) => typeof f.mimeType === "string" && f.mimeType.startsWith("audio/") && f.url)
    .sort((a: any, b: any) => (b.bitrate ?? 0) - (a.bitrate ?? 0));
  if (audio.length > 0) return { url: audio[0].url, mimeType: audio[0].mimeType, bitrate: audio[0].bitrate, quality: audio[0].audioQuality, client: "unknown" };
  const combined = (sd.formats ?? []).filter((f: any) => f.url);
  if (combined.length > 0) return { url: combined[0].url, mimeType: combined[0].mimeType, client: "unknown" };
  return null;
}

async function tryClient(videoId: string, clientName: string, clientVersion: string, headers: Record<string, string>, body: object): Promise<StreamResult | null> {
  try {
    const resp = await fetch(PLAYER_URL, {
      method: "POST",
      signal: AbortSignal.timeout(10000),
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const result = extractAudio(data);
    if (result) { result.client = clientName; return result; }
    return null;
  } catch {
    return null;
  }
}

async function tryEmbedPlayer(videoId: string, embedMeta: { apiKey: string; visitorData: string; clientVersion: string }): Promise<StreamResult | null> {
  const { apiKey, visitorData, clientVersion } = embedMeta;
  try {
    const resp = await fetch(`https://www.youtube.com/youtubei/v1/player?key=${apiKey}`, {
      method: "POST",
      signal: AbortSignal.timeout(10000),
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.6422.165 Safari/537.36",
        "Referer": `https://www.youtube.com/embed/${videoId}`,
        "Origin": "https://www.youtube.com",
        ...(visitorData ? { "X-Goog-Visitor-Id": visitorData } : {}),
      },
      body: JSON.stringify({
        videoId,
        context: {
          client: { clientName: "WEB_EMBEDDED_PLAYER", clientVersion, hl: "en", gl: "US", ...(visitorData ? { visitorData } : {}) },
          thirdParty: { embedUrl: `https://www.youtube.com/embed/${videoId}` },
        },
      }),
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    const result = extractAudio(data);
    if (result) { result.client = "WEB_EMBEDDED_PLAYER"; return result; }
    return null;
  } catch {
    return null;
  }
}

async function resolveStream(videoId: string): Promise<StreamResult | null> {
  const embedMeta = await getVisitorDataFromEmbed(videoId);

  const attempts = [
    tryClient(videoId, "ANDROID", "19.09.37", {
      "User-Agent": "com.google.android.youtube/19.09.37 (Linux; U; Android 12; GB) gzip",
    }, {
      videoId,
      context: { client: { clientName: "ANDROID", clientVersion: "19.09.37", androidSdkVersion: 30, hl: "en", gl: "US" } },
    }),
    tryClient(videoId, "ANDROID_MUSIC", "5.29.52", {
      "User-Agent": "com.google.android.apps.youtube.music/5.29.52-goog (Linux; U; Android 12; GB) gzip",
    }, {
      videoId,
      context: { client: { clientName: "ANDROID_MUSIC", clientVersion: "5.29.52", androidSdkVersion: 30, hl: "en", gl: "US" } },
    }),
    tryClient(videoId, "IOS", "19.09.3", {
      "User-Agent": "com.google.ios.youtube/19.09.3 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)",
    }, {
      videoId,
      context: { client: { clientName: "IOS", clientVersion: "19.09.3", deviceMake: "Apple", deviceModel: "iPhone14,3", osName: "iPhone", osVersion: "15.6.0", hl: "en", gl: "US" } },
    }),
    tryEmbedPlayer(videoId, embedMeta),
  ];

  const results = await Promise.allSettled(attempts);
  for (const r of results) {
    if (r.status === "fulfilled" && r.value) return r.value;
  }
  return null;
}

router.get("/stream", async (req, res) => {
  const id = (req.query.id as string | undefined)?.trim();
  if (!id) {
    res.status(400).json({ error: "Missing 'id' parameter" });
    return;
  }

  try {
    const result = await resolveStream(id);
    if (result) {
      res.json(result);
      return;
    }

    res.status(451).json({
      error: "stream_unavailable_from_server",
      message: "YouTube blocks server-side stream resolution from datacenter IPs. Use client-side InnerTube or the embed fallback.",
      fallback: {
        type: "embed",
        embedUrl: `https://www.youtube.com/embed/${id}?autoplay=1`,
        watchUrl: `https://youtu.be/${id}`,
        nocookieEmbedUrl: `https://www.youtube-nocookie.com/embed/${id}?autoplay=1`,
      },
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message ?? "Stream resolution failed" });
  }
});

export default router;

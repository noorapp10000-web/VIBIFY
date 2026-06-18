import { Router } from "express";

const router = Router();

const INNERTUBE_PLAYER_URL =
  "https://www.youtube.com/youtubei/v1/player";

interface ClientConfig {
  clientName: string;
  clientVersion: string;
  userAgent: string;
  extra?: Record<string, unknown>;
}

const CLIENTS: ClientConfig[] = [
  {
    clientName: "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
    clientVersion: "2.0",
    userAgent:
      "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1",
  },
  {
    clientName: "IOS",
    clientVersion: "19.09.3",
    userAgent:
      "com.google.ios.youtube/19.09.3 (iPhone14,3; U; CPU iOS 15_6 like Mac OS X)",
    extra: { deviceMake: "Apple", deviceModel: "iPhone14,3", osName: "iPhone", osVersion: "15.6.0" },
  },
  {
    clientName: "WEB_EMBEDDED_PLAYER",
    clientVersion: "2.20240101.01.00",
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  },
];

async function fetchStreamingData(videoId: string): Promise<any> {
  for (const client of CLIENTS) {
    try {
      const payload: any = {
        videoId,
        context: {
          client: {
            clientName: client.clientName,
            clientVersion: client.clientVersion,
            hl: "en",
            gl: "US",
            ...(client.extra ?? {}),
          },
        },
      };

      const resp = await fetch(INNERTUBE_PLAYER_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": client.userAgent,
          "X-YouTube-Client-Name": client.clientName,
          "X-YouTube-Client-Version": client.clientVersion,
        },
        body: JSON.stringify(payload),
      });

      if (!resp.ok) continue;

      const data: any = await resp.json();
      const streamingData = data?.streamingData;
      if (!streamingData) continue;

      const adaptive: any[] = streamingData.adaptiveFormats ?? [];
      const audioFormats = adaptive
        .filter(
          (f: any) =>
            typeof f.mimeType === "string" &&
            f.mimeType.startsWith("audio/") &&
            f.url,
        )
        .sort((a: any, b: any) => (b.bitrate ?? 0) - (a.bitrate ?? 0));

      if (audioFormats.length > 0) {
        return {
          url: audioFormats[0].url,
          mimeType: audioFormats[0].mimeType,
          bitrate: audioFormats[0].bitrate,
          quality: audioFormats[0].audioQuality,
          client: client.clientName,
        };
      }

      const combined: any[] = (streamingData.formats ?? []).filter(
        (f: any) => f.url,
      );
      if (combined.length > 0) {
        return {
          url: combined[0].url,
          mimeType: combined[0].mimeType,
          client: client.clientName,
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}

router.get("/stream", async (req, res) => {
  const id = req.query.id as string | undefined;

  if (!id || id.trim() === "") {
    res.status(400).json({ error: "Missing query parameter 'id'" });
    return;
  }

  try {
    const result = await fetchStreamingData(id.trim());
    if (!result) {
      res.status(404).json({ error: "No playable stream found for this video" });
      return;
    }
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message ?? "Stream resolution failed" });
  }
});

export default router;

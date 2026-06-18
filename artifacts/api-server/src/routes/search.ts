import { Router } from "express";

const router = Router();

const INNERTUBE_SEARCH_URL =
  "https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

router.get("/search", async (req, res) => {
  const q = req.query.q as string | undefined;
  const limit = Math.min(Number(req.query.limit ?? 20), 50);

  if (!q || q.trim() === "") {
    res.status(400).json({ error: "Missing query parameter 'q'" });
    return;
  }

  try {
    const payload = {
      context: {
        client: {
          clientName: "WEB",
          clientVersion: "2.20240101.01.00",
          hl: "en",
          gl: "US",
        },
      },
      query: q,
      params: "EgIQAQ==",
    };

    const ytResp = await fetch(INNERTUBE_SEARCH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent":
          "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9",
        "X-YouTube-Client-Name": "1",
        "X-YouTube-Client-Version": "2.20240101.01.00",
      },
      body: JSON.stringify(payload),
    });

    if (!ytResp.ok) {
      res
        .status(502)
        .json({ error: `YouTube returned ${ytResp.status}` });
      return;
    }

    const data: any = await ytResp.json();

    const sectionList =
      data?.contents?.twoColumnSearchResultsRenderer?.primaryContents
        ?.sectionListRenderer?.contents ?? [];

    const tracks: any[] = [];

    for (const section of sectionList) {
      const items: any[] =
        section?.itemSectionRenderer?.contents ?? [];
      for (const item of items) {
        const vr = item?.videoRenderer;
        if (!vr) continue;
        const vid: string = vr.videoId;
        if (!vid) continue;

        const title: string =
          vr.title?.runs?.[0]?.text ?? vid;
        const channel: string =
          vr.ownerText?.runs?.[0]?.text ?? "Unknown";
        const durationText: string | undefined =
          vr.lengthText?.simpleText;

        tracks.push({
          id: vid,
          title,
          artist: channel,
          duration_text: durationText ?? null,
          thumbnail_url: `https://i.ytimg.com/vi/${vid}/hqdefault.jpg`,
          youtube_video_id: vid,
        });

        if (tracks.length >= limit) break;
      }
      if (tracks.length >= limit) break;
    }

    res.json({ query: q, total: tracks.length, tracks });
  } catch (err: any) {
    res.status(500).json({ error: err.message ?? "Search failed" });
  }
});

export default router;

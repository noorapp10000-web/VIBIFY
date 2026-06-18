// ============================================================
//  Vibify API — Cloudflare Worker
//  Endpoints:
//    GET /search?q=<query>&limit=<n>   → {tracks:[...]}
//    GET /stream?id=<videoId>          → {url:"..."} or 451 + {fallback:{embedUrl,...}}
//    GET /info?id=<videoId>            → {id,title,artist,duration_seconds,thumbnail_url}
// ============================================================

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: CORS_HEADERS,
  });
}

// ── InnerTube helpers ─────────────────────────────────────────────────────────

const INNERTUBE_SEARCH_URL =
  'https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

const INNERTUBE_PLAYER_URL =
  'https://www.youtube.com/youtubei/v1/player?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';

async function innertubeSearch(query, limit = 20) {
  const payload = {
    context: {
      client: {
        clientName: 'WEB',
        clientVersion: '2.20240101.01.00',
        hl: 'en',
        gl: 'US',
      },
    },
    query,
    params: 'EgIQAQ==', // only videos
  };

  const resp = await fetch(INNERTUBE_SEARCH_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'X-YouTube-Client-Name': '1',
      'X-YouTube-Client-Version': '2.20240101.01.00',
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) throw new Error(`InnerTube search HTTP ${resp.status}`);
  const data = await resp.json();

  const sections =
    data?.contents?.twoColumnSearchResultsRenderer?.primaryContents
      ?.sectionListRenderer?.contents ?? [];

  const tracks = [];
  for (const section of sections) {
    const items = section?.itemSectionRenderer?.contents ?? [];
    for (const item of items) {
      const vr = item?.videoRenderer;
      if (!vr) continue;
      const vid = vr.videoId;
      if (!vid) continue;

      const title = vr.title?.runs?.[0]?.text ?? vid;
      const artist = vr.ownerText?.runs?.[0]?.text ?? 'Unknown';
      const durationText = vr.lengthText?.simpleText ?? null;
      const thumbnailUrl = `https://i.ytimg.com/vi/${vid}/hqdefault.jpg`;

      tracks.push({
        id: vid,
        title,
        artist,
        duration_text: durationText,
        thumbnail_url: thumbnailUrl,
      });
      if (tracks.length >= limit) break;
    }
    if (tracks.length >= limit) break;
  }
  return tracks;
}

// Try ANDROID client first, then TV client
async function innertubePlayerStream(videoId) {
  // Attempt 1: ANDROID client (returns unencrypted URLs when not blocked)
  const clients = [
    {
      clientName: 'ANDROID',
      clientVersion: '19.09.37',
      androidSdkVersion: 30,
      userAgent:
        'com.google.android.youtube/19.09.37 (Linux; U; Android 12; GB) gzip',
    },
    {
      clientName: 'ANDROID_MUSIC',
      clientVersion: '7.27.52',
      androidSdkVersion: 30,
      userAgent:
        'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 12) gzip',
    },
    {
      clientName: 'TVHTML5',
      clientVersion: '7.20240101.18.00',
    },
  ];

  for (const client of clients) {
    try {
      const payload = {
        videoId,
        context: { client },
        params: '2AMBCgIQBg==',
      };

      const headers = {
        'Content-Type': 'application/json',
      };
      if (client.userAgent) {
        headers['User-Agent'] = client.userAgent;
      }

      const resp = await fetch(INNERTUBE_PLAYER_URL, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });

      if (!resp.ok) continue;
      const data = await resp.json();

      const streaming = data?.streamingData;
      if (!streaming) continue;

      const adaptive = streaming.adaptiveFormats ?? [];
      const formats = streaming.formats ?? [];
      const all = [...adaptive, ...formats];

      // Prefer audio-only, highest bitrate
      const audioFormats = all.filter(
        (f) =>
          f.mimeType?.startsWith('audio/') &&
          f.url &&
          !f.signatureCipher &&
          !f.cipher
      );

      if (audioFormats.length > 0) {
        audioFormats.sort((a, b) => (b.bitrate ?? 0) - (a.bitrate ?? 0));
        return { url: audioFormats[0].url, client: client.clientName };
      }

      // Fallback: combined format with url
      const combined = all.filter((f) => f.url && !f.signatureCipher);
      if (combined.length > 0) {
        return { url: combined[0].url, client: client.clientName };
      }
    } catch (_) {
      // try next client
    }
  }

  return null;
}

// ── Route handlers ────────────────────────────────────────────────────────────

async function handleSearch(url) {
  const q = url.searchParams.get('q') ?? '';
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '20', 10), 50);

  if (!q.trim()) {
    return json({ error: 'Missing query parameter "q"' }, 400);
  }

  try {
    const tracks = await innertubeSearch(q, limit);
    return json({ tracks, total: tracks.length, query: q });
  } catch (err) {
    return json({ error: err.message }, 500);
  }
}

async function handleStream(url) {
  const id = url.searchParams.get('id') ?? '';
  if (!id) return json({ error: 'Missing "id" parameter' }, 400);

  const result = await innertubePlayerStream(id);
  if (result) {
    return json({ url: result.url, client: result.client, video_id: id });
  }

  // YouTube blocked this server — return embed fallback with 451 status
  return json(
    {
      error: 'Stream unavailable from server (datacenter IP blocked)',
      fallback: {
        embedUrl: `https://www.youtube.com/embed/${id}?autoplay=1`,
        nocookieEmbedUrl: `https://www.youtube-nocookie.com/embed/${id}?autoplay=1&controls=0&mute=0`,
      },
    },
    451
  );
}

async function handleInfo(url) {
  const id = url.searchParams.get('id') ?? '';
  if (!id) return json({ error: 'Missing "id" parameter' }, 400);

  // 1. Try YouTube oEmbed (works from any IP, gives title + author + thumbnail)
  try {
    const oembedUrl =
      `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${id}&format=json`;
    const resp = await fetch(oembedUrl, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
    });
    if (resp.ok) {
      const data = await resp.json();
      return json({
        id,
        title: data.title ?? id,
        artist: data.author_name ?? 'Unknown',
        duration_seconds: 0,
        youtube_video_id: id,
        thumbnail_url: data.thumbnail_url ?? `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
      });
    }
  } catch (_) {}

  // 2. Fallback: construct basic info from video ID
  return json({
    id,
    title: id,
    artist: 'Unknown',
    duration_seconds: 0,
    youtube_video_id: id,
    thumbnail_url: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
  });
}

// ── Main fetch handler ────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/search') return handleSearch(url);
    if (path === '/stream') return handleStream(url);
    if (path === '/info') return handleInfo(url);

    // Health check
    if (path === '/' || path === '/health') {
      return json({ status: 'ok', service: 'Vibify API', version: '2.0' });
    }

    return json({ error: 'Not found' }, 404);
  },
};

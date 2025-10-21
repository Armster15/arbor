import yt_dlp
import os
from pathlib import Path
import tempfile
import json


def stream(url: str):
    # Configuration options for streaming (no download)
    # Options: https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/__init__.py#L776
    ydl_opts = {
        "format": "bestaudio[ext=m4a]/bestaudio",
        "verbose": True,  # Shows detailed output
        "nocheckcertificate": True,  # Ignore certificate errors (happens on physical device)
        # Ensure only single videos are processed, no playlists
        "playlistend": 1,  # Only process the first item (single video)
        "noplaylist": True,  # Do not process playlists
    }

    # Extract video information and streaming URL without downloading
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        print(f"Extracting streaming info from: {url}")

        info = ydl.extract_info(url, download=False)

        if info is None:
            raise Exception("Failed to retrieve video information")

        # Get the streaming URL from the selected format
        streaming_url = None
        if "url" in info:
            streaming_url = info["url"]
        elif "formats" in info:
            # Find the best audio format
            audio_formats = [f for f in info["formats"] if f.get("acodec") != "none"]
            if audio_formats:
                # Sort by quality and select the best
                audio_formats.sort(key=lambda x: x.get("abr", 0), reverse=True)
                streaming_url = audio_formats[0].get("url")

        if not streaming_url:
            raise Exception("No streaming URL found for this video")

        print(f"Streaming URL: {streaming_url}")

        title = info.get("title", "Unknown Title")
        # Prefer artist, then uploader/channel, then None
        artist = (
            info.get("artist") or info.get("uploader") or info.get("channel") or None
        )

        # Choose thumbnail: prefer square art (common for music); else highest resolution
        thumbnails = info.get("thumbnails") or []
        thumbnail_info = None
        thumbnail_url = None

        def _dims(t):
            if not isinstance(t, dict):
                return (0, 0)
            w = t.get("width") or 0
            h = t.get("height") or 0
            try:
                return (int(w), int(h))
            except Exception:
                return (0, 0)

        def _area(t):
            w, h = _dims(t)
            return w * h

        def _is_square(t, tol=2):
            w, h = _dims(t)
            return w > 0 and h > 0 and abs(w - h) <= tol

        if isinstance(thumbnails, list) and thumbnails:
            square_thumbs = [t for t in thumbnails if _is_square(t)]
            if square_thumbs:
                # Largest square by area
                thumbnail_info = max(square_thumbs, key=_area)
            else:
                # Fallback: largest by area
                thumbnail_info = max(thumbnails, key=_area)
            thumbnail_url = (thumbnail_info or {}).get("url")
        else:
            # Fallback to top-level thumbnail string if thumbnails list is absent
            thumbnail_url = info.get("thumbnail")

        # Extract dimensions if available
        thumb_w = None
        thumb_h = None
        if isinstance(thumbnail_info, dict):
            try:
                w = thumbnail_info.get("width")
                h = thumbnail_info.get("height")
                thumb_w = int(w) if isinstance(w, (int, float)) else None
                thumb_h = int(h) if isinstance(h, (int, float)) else None
            except Exception:
                thumb_w = None
                thumb_h = None

        meta = {
            "streaming_url": streaming_url,
            "title": title,
            "artist": artist,
            "thumbnail_url": thumbnail_url,
            "thumbnail_width": thumb_w,
            "thumbnail_height": thumb_h,
            "thumbnail_is_square": (
                thumb_w is not None and thumb_h is not None and thumb_w == thumb_h
            ),
            "duration": info.get("duration"),
        }

        return json.dumps(meta)

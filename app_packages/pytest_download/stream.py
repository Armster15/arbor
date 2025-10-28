import yt_dlp
import json


def stream(url: str):
    # Configuration options for streaming (no download)
    # Options: https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/__init__.py#L776
    ext_order = ["m4a", "mp3", "webm", "opus", "aac", "ogg"]

    format_selectors = [f"bestaudio[ext={ext}]" for ext in ext_order]
    # Additional fallback to AAC family, then any bestaudio.
    format_selectors += ["bestaudio[acodec^=mp4a]", "bestaudio"]

    ydl_opts = {
        "format": "/".join(format_selectors),
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

        # Helper to pick the best matching audio-only format when yt-dlp doesn't give a top-level URL
        def pick_best_audio_format(formats, preference_order):
            if not isinstance(formats, list):
                return None
            audio_only = [
                f
                for f in formats
                if isinstance(f, dict)
                and f.get("vcodec") in ("none", None)
                and f.get("acodec") not in ("none", None)
                and f.get("url")
            ]
            if not audio_only:
                return None

            # Rank by: container preference, then bitrate (abr), then filesize (if present)
            def rank_key(f):
                ext = (f.get("ext") or "").lower()
                try:
                    pref_idx = preference_order.index(ext)
                except ValueError:
                    pref_idx = len(preference_order)
                # Higher abr preferred; missing treated as 0
                abr = f.get("abr") or 0
                filesize = f.get("filesize") or f.get("filesize_approx") or 0
                # Lower pref_idx is better; higher abr is better; larger filesize can sometimes indicate quality
                return (
                    pref_idx,
                    -float(abr) if isinstance(abr, (int, float)) else -0.0,
                    -float(filesize) if isinstance(filesize, (int, float)) else -0.0,
                )

            audio_only.sort(key=rank_key)
            return audio_only[0]

        # Attempt to get the selected format url
        streaming_url = None
        selected_ext = None
        selected_acodec = None
        selected_mime = None

        if isinstance(info, dict):
            # yt-dlp will usually expose the chosen format on top-level url/ext/acodec for audio-only
            streaming_url = info.get("url")
            selected_ext = info.get("ext") or None
            selected_acodec = info.get("acodec") or None
            selected_mime = info.get("protocol") or None  # not true MIME; refine below

            if not streaming_url:
                best = pick_best_audio_format(info.get("formats"), ext_order)
                if best:
                    streaming_url = best.get("url")
                    selected_ext = best.get("ext")
                    selected_acodec = best.get("acodec")
                    selected_mime = best.get("mime_type") or best.get(
                        "http_headers", {}
                    ).get("Content-Type")

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

        # Infer a reasonable MIME type from extension if yt-dlp didn't provide one
        if not selected_mime and selected_ext:
            ext_to_mime = {
                "m4a": "audio/mp4",
                "mp4": "audio/mp4",
                "mp3": "audio/mpeg",
                "webm": "audio/webm",
                "opus": "audio/ogg",
                "ogg": "audio/ogg",
                "aac": "audio/aac",
                "wav": "audio/wav",
            }
            selected_mime = ext_to_mime.get(selected_ext.lower())

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

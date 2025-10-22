import yt_dlp
import os
from pathlib import Path
import tempfile
import json


def download(url: str):
    # Configuration options matching the command line flags
    # Options: https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/__init__.py#L776
    ydl_opts = {
        "format": "bestaudio[ext=m4a]/bestaudio",
        "nopostoverwrites": True,
        "postprocessors": [],  # No post-processors at all
        "verbose": True,  # Shows detailed output including ffmpeg usage'
        #
        # NOTE:
        # The video appears longer because without ffmpeg (and with --fixup never, which is required for no ffmpeg/ffprobe), yt-dlp can't correct
        # YouTube's mismatched duration metadata, so it keeps the raw stream length-this option is needed
        # since ffmpeg isn't available to fix it automatically.
        "fixup": "never",  # Disable all fixup post-processors
        #
        # Ensure only single videos are downloaded, no playlists
        "playlistend": 1,  # Only download the first item (single video)
        "noplaylist": True,  # Do not download playlists
        "nocheckcertificate": True,  # Ignore certificate errors (happens on physical device)
    }

    # Select iOS-writable locations
    home = Path.home()
    tmp_dir = Path(tempfile.gettempdir())
    caches_dir = home / "Library" / "Caches"
    yt_cache_dir = caches_dir / "yt-dlp"
    output_dir = tmp_dir  # Prefer tmp for downloads to avoid backups

    # Ensure directories exist
    output_dir.mkdir(parents=True, exist_ok=True)
    yt_cache_dir.mkdir(parents=True, exist_ok=True)

    # Tell yt-dlp where to write files and cache
    ydl_opts.update(
        {
            "outtmpl": str(output_dir / "%(uploader_id)s-%(id)s.%(ext)s"),
            "cachedir": str(yt_cache_dir),
        }
    )

    # Download the video
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        print(f"Downloading video from: {url}")
        print(f"Downloading video to: {output_dir}")
        print(f"Using cache dir: {yt_cache_dir}")

        info = ydl.extract_info(url, download=True)

        filename = ydl.prepare_filename(info)
        full_path = os.path.abspath(filename)
        print(f"Downloaded file: {full_path}")

        if info is None:
            raise Exception("Failed to retrieve video information (manually thrown)")

        title = info.get("title") or Path(full_path).stem
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
            "path": full_path,
            "title": title,
            "artist": artist,
            "thumbnail_url": thumbnail_url,
            "thumbnail_width": thumb_w,
            "thumbnail_height": thumb_h,
            "thumbnail_is_square": (
                thumb_w is not None and thumb_h is not None and thumb_w == thumb_h
            ),
        }

        return json.dumps(meta)

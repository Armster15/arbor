import yt_dlp
import os
from pathlib import Path
import tempfile

version = "1.0.0"


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
            "outtmpl": str(output_dir / "%(title)s.%(ext)s"),
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

        return full_path

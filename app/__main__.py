# Your application code should be placed in this directory.
#
# The native code will be looking for a {{ cookiecutter.module_name }}/__main__.py file as the entry point.

import yt_dlp
import os
from pathlib import Path
import tempfile

# Configuration options matching the command line flags
ydl_opts = {
    "format": "worst",  # Download the worst quality available
    "nopostoverwrites": True,
    "postprocessors": [],  # No post-processors at all
    "verbose": True,  # Shows detailed output including ffmpeg usage'
    "fixup": "never",  # Disable all fixup post-processors
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

# The video URL
url = "https://www.youtube.com/watch?v=J4kj6Ds4mrA"

# Download the video
with yt_dlp.YoutubeDL(ydl_opts) as ydl:
    print(f"Downloading video to: {output_dir}")
    print(f"Using cache dir: {yt_cache_dir}")
    info = ydl.extract_info(url, download=True)
    filename = ydl.prepare_filename(info)
    full_path = os.path.abspath(filename)
    print(f"Downloaded file: {full_path}")

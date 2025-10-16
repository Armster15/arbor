# Your application code should be placed in this directory.
#
# The native code will be looking for a {{ cookiecutter.module_name }}/__main__.py file as the entry point.

import yt_dlp

# Print version and basic metadata
print(f"yt-dlp version: {yt_dlp.version.__version__}")

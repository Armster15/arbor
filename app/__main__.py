# Your application code should be placed in this directory.
#
# The native code will be looking for a {{ cookiecutter.module_name }}/__main__.py file as the entry point.

from yt_dlp import YoutubeDL


def main():
    url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    ydl_opts = {"quiet": True}

    with YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        print(info.get("title"))


if __name__ == "__main__":
    main()

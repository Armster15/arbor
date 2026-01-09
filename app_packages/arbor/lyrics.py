from ytmusicapi import YTMusic


def get_lyrics_from_youtube(video_id: str) -> list[tuple[int, str]] | list[str] | None:
    """
    Get lyrics from YouTube Music for a given video ID.

    Args:
        video_id: The YouTube video ID (e.g. "dQw4w9WgXcQ")

    Returns:
        If timestamps are available: Array<[number, string]>, where the first element
        is the start time in milliseconds and the second element is the text.

        Else if lyrics but no timestamps: Array<string>

        Else: None
    """
    ytmusic = YTMusic()

    watch = ytmusic.get_watch_playlist(videoId=video_id, limit=1)
    browse_id = watch.get("lyrics")

    if not browse_id or not isinstance(browse_id, str):
        return None

    lyrics = ytmusic.get_lyrics(browse_id, timestamps=True)

    if lyrics is None:
        return None

    lyrics = lyrics.get("lyrics")

    # Has timestamps
    if isinstance(lyrics, list):
        # [ [start_time_ms: number, text: string], ... ]
        lines: list[tuple[int, str]] = [(line.start_time, line.text) for line in lyrics]
        return lines

    # Does not have timestamps and is just a string separated by `\n`s
    elif isinstance(lyrics, str):
        return lyrics.split("\n")

    else:
        return None

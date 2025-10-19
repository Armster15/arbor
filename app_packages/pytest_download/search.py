from ytmusicapi import YTMusic
import json
import re

ytmusic = YTMusic()


def search(query: str):
    raw_results = ytmusic.search(query, filter="songs", limit=15)
    results = []

    for result in raw_results:
        videoId = result.get("videoId")

        thumbnail = result.get("thumbnails") and result["thumbnails"][-1]
        thumbnail_width = thumbnail and thumbnail.get("width")
        thumbnail_height = thumbnail and thumbnail.get("height")
        thumbnail_is_square = thumbnail_width == thumbnail_height
        thumbnail_url = thumbnail and thumbnail.get("url")

        if thumbnail_url and thumbnail_is_square:
            # upscale thumbnail image to 400x400
            thumbnail_url = re.sub(r"w\d+-h\d+", "w400-h400", thumbnail_url)
            thumbnail_width = 400
            thumbnail_height = 400
        elif videoId:
            thumbnail_url = f"https://i.ytimg.com/vi/{videoId}/maxresdefault.jpg"
        else:
            thumbnail_url = None

        artists = result.get("artists")
        if not isinstance(artists, list) or len(artists) == 0:
            artists = None
        else:
            artists = [artist["name"] for artist in artists]

        results.append(
            {
                "title": result.get("title"),
                "artists": artists,
                "youtube_url": f"https://www.youtube.com/watch?v={videoId}",
                "views": result.get("views"),
                "duration": result.get("duration"),
                "is_explicit": result.get("isExplicit"),
                "thumbnail_url": thumbnail_url,
                "thumbnail_is_square": thumbnail_is_square,
                "thumbnail_width": thumbnail_width,
                "thumbnail_height": thumbnail_height,
            }
        )

    data = json.dumps(results)

    return data

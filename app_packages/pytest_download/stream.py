import yt_dlp
import json
import threading
import base64
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, urlencode
import requests


def stream(url: str):
    # Configuration options for streaming (no download)
    # Options: https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/__init__.py#L776
    # Prefer Apple-compatible containers only to avoid AVAudioConverter errors
    # Strictly choose progressive HTTPS AAC in MP4 (m4a) or raw AAC; avoid HLS (m3u8) and DASH.
    ext_order = ["m4a", "aac"]

    # Progressive only, HTTPS only
    format_selectors = [
        "bestaudio[ext=m4a][vcodec=none][protocol^=https]",
        "bestaudio[acodec^=mp4a][vcodec=none][protocol^=https]",
        "bestaudio[ext=aac][vcodec=none][protocol^=https]",
    ]

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
        def pick_best_audio_format(formats, preference_order, prefer_itag=None):
            if not isinstance(formats, list):
                return None
            # Strictly filter to progressive HTTP(S) audio-only, non-DASH, non-fragmented
            audio_only = [
                f
                for f in formats
                if isinstance(f, dict)
                and f.get("vcodec") in ("none", None)
                and f.get("acodec") not in ("none", None)
                and f.get("url")
                and (f.get("protocol") in ("https", "http"))
                and not f.get("is_dash")
                and not f.get("fragmented")
                and not f.get("fragments")
                and not f.get("manifest_url")
                and ("dash" not in (f.get("container") or "").lower())
            ]
            if not audio_only:
                return None

            # If a specific itag is preferred and present, pick it directly
            if prefer_itag is not None:
                by_itag = [
                    f for f in audio_only if f.get("format_id") == str(prefer_itag)
                ]
                if by_itag:
                    return by_itag[0]

            # Rank by: container preference, then bitrate (abr), then filesize (if present)
            def rank_key(f):
                ext = (f.get("ext") or "").lower()
                try:
                    pref_idx = preference_order.index(ext)
                except ValueError:
                    pref_idx = len(preference_order)
                protocol = f.get("protocol") or ""
                # Prefer HTTPS progressive, avoid HLS and DASH entirely
                if protocol in ("https", "http"):
                    proto_rank = 0
                elif protocol.startswith("m3u8"):
                    proto_rank = 3
                elif protocol == "http_dash_segments":
                    proto_rank = 4
                else:
                    proto_rank = 2
                # Higher abr preferred; missing treated as 0
                abr = f.get("abr") or 0
                filesize = f.get("filesize") or f.get("filesize_approx") or 0
                # Lower pref_idx is better; higher abr is better; larger filesize can sometimes indicate quality
                return (
                    pref_idx,
                    proto_rank,
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
        selected_protocol = None
        selected_asr = None
        selected_abr = None

        if isinstance(info, dict):
            # yt-dlp will usually expose the chosen format on top-level url/ext/acodec for audio-only
            streaming_url = info.get("url")
            selected_ext = info.get("ext") or None
            selected_acodec = info.get("acodec") or None
            selected_protocol = info.get("protocol") or None
            selected_mime = None  # refine below

            if not streaming_url:
                prefer_itag = (
                    140
                    if (info.get("extractor_key") or "").lower().startswith("youtube")
                    else None
                )
                best = pick_best_audio_format(
                    info.get("formats"), ext_order, prefer_itag=prefer_itag
                )
                if best:
                    streaming_url = best.get("url")
                    selected_ext = best.get("ext")
                    selected_acodec = best.get("acodec")
                    selected_mime = best.get("mime_type") or best.get(
                        "http_headers", {}
                    ).get("Content-Type")
                    selected_protocol = best.get("protocol")
                    selected_asr = best.get("asr")
                    selected_abr = best.get("abr")
            # If selected format is not Apple-compatible, re-pick from formats using our ext_order
            allowed_exts = set(ext_order)
            if selected_ext and selected_ext.lower() not in allowed_exts:
                prefer_itag = (
                    140
                    if (info.get("extractor_key") or "").lower().startswith("youtube")
                    else None
                )
                best = pick_best_audio_format(
                    info.get("formats"), ext_order, prefer_itag=prefer_itag
                )
                if best:
                    streaming_url = best.get("url") or streaming_url
                    selected_ext = best.get("ext") or selected_ext
                    selected_acodec = best.get("acodec") or selected_acodec
                    selected_mime = best.get("mime_type") or selected_mime
                    selected_protocol = best.get("protocol") or selected_protocol
                    selected_asr = best.get("asr") or selected_asr
                    selected_abr = best.get("abr") or selected_abr
            # If protocol is not HTTPS/HTTP progressive, also re-pick
            if selected_protocol not in ("https", "http"):
                prefer_itag = (
                    140
                    if (info.get("extractor_key") or "").lower().startswith("youtube")
                    else None
                )
                best = pick_best_audio_format(
                    info.get("formats"), ext_order, prefer_itag=prefer_itag
                )
                if best:
                    streaming_url = best.get("url") or streaming_url
                    selected_ext = best.get("ext") or selected_ext
                    selected_acodec = best.get("acodec") or selected_acodec
                    selected_mime = best.get("mime_type") or selected_mime
                    selected_protocol = best.get("protocol") or selected_protocol
                    selected_asr = best.get("asr") or selected_asr
                    selected_abr = best.get("abr") or selected_abr

        if not streaming_url:
            raise Exception("No streaming URL found for this video")

        print(f"Streaming URL: {streaming_url}")

        # Try to find and preserve any upstream headers yt-dlp recommends for this URL
        selected_headers = None
        try:
            fmts = info.get("formats") or []
            match = next(
                (
                    f
                    for f in fmts
                    if isinstance(f, dict) and f.get("url") == streaming_url
                ),
                None,
            )
            if match and isinstance(match, dict):
                selected_headers = match.get("http_headers")
            if not selected_headers and isinstance(info, dict):
                selected_headers = info.get("http_headers")
        except Exception:
            selected_headers = None

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
                "aac": "audio/aac",
            }
            selected_mime = ext_to_mime.get(selected_ext.lower())

        # Build a local proxy URL that injects required headers and forwards Range requests
        proxied = _ensure_proxy_and_build_url(streaming_url, selected_headers)

        meta = {
            "streaming_url": proxied or streaming_url,
            "title": title,
            "artist": artist,
            "thumbnail_url": thumbnail_url,
            "thumbnail_width": thumb_w,
            "thumbnail_height": thumb_h,
            "thumbnail_is_square": (
                thumb_w is not None and thumb_h is not None and thumb_w == thumb_h
            ),
            "duration": info.get("duration"),
            # Debug/diagnostic fields to trace playback issues
            "ext": selected_ext,
            "acodec": selected_acodec,
            "mime_type": selected_mime,
            "protocol": selected_protocol,
            "asr": selected_asr,
            "abr": selected_abr,
            "extractor_key": info.get("extractor_key"),
        }

        return json.dumps(meta)


# -----------------------
# Local header-injecting proxy
# -----------------------

_proxy_server = None
_proxy_thread = None
_proxy_port = None


class _ProxyHandler(BaseHTTPRequestHandler):
    # Disable logging spam
    def log_message(self, format, *args):
        return

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/proxy":
            self.send_response(404)
            self.end_headers()
            return
        qs = parse_qs(parsed.query)
        upstream = (qs.get("u") or [None])[0]
        headers_b64 = (qs.get("h") or [None])[0]
        if not upstream:
            self.send_response(400)
            self.end_headers()
            return

        try:
            upstream_headers = (
                json.loads(base64.b64decode(headers_b64 or b"{}"))
                if headers_b64
                else {}
            )
        except Exception:
            upstream_headers = {}

        # Merge Range and Accept headers from client
        forward_headers = dict(upstream_headers)
        if "Range" in self.headers:
            forward_headers["Range"] = self.headers["Range"]
        if "Accept" in self.headers:
            forward_headers["Accept"] = self.headers["Accept"]
        if "User-Agent" not in forward_headers and "User-Agent" in self.headers:
            forward_headers["User-Agent"] = self.headers["User-Agent"]

        try:
            with requests.get(
                upstream, headers=forward_headers, stream=True, timeout=(10, 120)
            ) as r:
                status = r.status_code
                self.send_response(status)
                # Pass through selected headers
                passthrough = [
                    "Content-Type",
                    "Content-Length",
                    "Accept-Ranges",
                    "Content-Range",
                    "Cache-Control",
                    "ETag",
                    "Last-Modified",
                    "Date",
                    "Server",
                ]
                for k in passthrough:
                    v = r.headers.get(k)
                    if v:
                        self.send_header(k, v)
                # Avoid chunked encoding when possible
                self.end_headers()

                for chunk in r.iter_content(chunk_size=64 * 1024):
                    if chunk:
                        self.wfile.write(chunk)
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            try:
                self.wfile.write(str(e).encode("utf-8"))
            except Exception:
                pass

    def do_HEAD(self):
        parsed = urlparse(self.path)
        if parsed.path != "/proxy":
            self.send_response(404)
            self.end_headers()
            return
        qs = parse_qs(parsed.query)
        upstream = (qs.get("u") or [None])[0]
        headers_b64 = (qs.get("h") or [None])[0]
        if not upstream:
            self.send_response(400)
            self.end_headers()
            return

        try:
            upstream_headers = (
                json.loads(base64.b64decode(headers_b64 or b"{}"))
                if headers_b64
                else {}
            )
        except Exception:
            upstream_headers = {}

        forward_headers = dict(upstream_headers)
        if "Range" in self.headers:
            forward_headers["Range"] = self.headers["Range"]
        if "Accept" in self.headers:
            forward_headers["Accept"] = self.headers["Accept"]
        if "User-Agent" not in forward_headers and "User-Agent" in self.headers:
            forward_headers["User-Agent"] = self.headers["User-Agent"]

        try:
            r = requests.head(
                upstream, headers=forward_headers, timeout=10, allow_redirects=True
            )
            self.send_response(r.status_code)
            passthrough = [
                "Content-Type",
                "Content-Length",
                "Accept-Ranges",
                "Content-Range",
                "Cache-Control",
                "ETag",
                "Last-Modified",
                "Date",
                "Server",
            ]
            for k in passthrough:
                v = r.headers.get(k)
                if v:
                    self.send_header(k, v)
            self.end_headers()
        except Exception as e:
            self.send_response(502)
            self.end_headers()


def _find_free_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    addr, port = s.getsockname()
    s.close()
    return port


def _ensure_proxy_started():
    global _proxy_server, _proxy_thread, _proxy_port
    if _proxy_server is not None:
        return _proxy_port
    port = _find_free_port()
    server = HTTPServer(("127.0.0.1", port), _ProxyHandler)
    thread = threading.Thread(target=server.serve_forever, name="ytproxy", daemon=True)
    thread.start()
    _proxy_server = server
    _proxy_thread = thread
    _proxy_port = port
    return port


def _ensure_proxy_and_build_url(upstream_url: str, best_headers: dict | None):
    if not upstream_url:
        return None
    port = _ensure_proxy_started()
    try:
        headers_json = json.dumps(best_headers or {}, separators=(",", ":"))
        headers_b64 = base64.b64encode(headers_json.encode("utf-8")).decode("ascii")
    except Exception:
        headers_b64 = ""
    q = urlencode({"u": upstream_url, "h": headers_b64})
    return f"http://127.0.0.1:{port}/proxy?{q}"

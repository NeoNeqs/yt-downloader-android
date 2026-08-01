"""
Runs inside Chaquopy's embedded CPython interpreter (called from Kotlin via
com.chaquo.python.Python — see YtDlpBridge.kt).

We drive yt-dlp through yt_dlp.main(argv), i.e. the exact same argument list
you'd type on a command line, rather than hand-building a ydl_opts dict.
Reason: --js-runtimes and friends are documented, stable *CLI* flags; the
internal Python dict key names for brand-new options move around between
releases and aren't part of yt-dlp's public API contract. main(argv) is.
"""

import os
import sys
import json
import traceback

import yt_dlp


class ProgressJSONLogger:
    """Emits one JSON line per event to stdout; Kotlin tails this to update
    the foreground-service notification and the in-app download list."""

    def _emit(self, kind, **fields):
        payload = {"type": kind, **fields}
        print("PROGRESS_JSON:" + json.dumps(payload), flush=True)

    def debug(self, msg):
        if msg.startswith("[download]"):
            self._emit("debug", message=msg)

    def info(self, msg):
        self._emit("info", message=msg)

    def warning(self, msg):
        self._emit("warning", message=msg)

    def error(self, msg):
        self._emit("error", message=msg)


def _progress_hook(d):
    if d["status"] == "downloading":
        print(
            "PROGRESS_JSON:"
            + json.dumps(
                {
                    "type": "downloading",
                    "filename": d.get("filename"),
                    "percent_str": d.get("_percent_str", "").strip(),
                    "eta": d.get("eta"),
                }
            ),
            flush=True,
        )
    elif d["status"] == "finished":
        print(
            "PROGRESS_JSON:"
            + json.dumps({"type": "finished", "filename": d.get("filename")}),
            flush=True,
        )


def download(
    url: str,
    output_dir: str,
    ffmpeg_path: str,
    node_runtime_path: str | None,
    native_lib_dir: str | None,
    cookies_file: str | None = None,
) -> dict:
    """
    Downloads `url` as audio-only into `output_dir`.
    Returns {"ok": True, "path": "<final file path>"} or {"ok": False, "error": "..."}.
    """

    # ffmpeg and node are dynamically linked (node especially — libssl, libcrypto,
    # ICU, etc). Android's dynamic linker won't find those co-installed .so files
    # unless LD_LIBRARY_PATH points at nativeLibraryDir; a subprocess we spawn
    # doesn't inherit the app process's own linker search path automatically.
    if native_lib_dir:
        existing = os.environ.get("LD_LIBRARY_PATH", "")
        os.environ["LD_LIBRARY_PATH"] = (
            native_lib_dir if not existing else f"{native_lib_dir}:{existing}"
        )

    argv = [
        url,
        "-x",  # extract audio
        "--audio-format", "mp3",
        "--audio-quality", "0",  # best
        "--embed-thumbnail",
        "--embed-metadata",
        "--add-metadata",
        "-o", os.path.join(output_dir, "%(title)s.%(ext)s"),
        "--ffmpeg-location", ffmpeg_path,
        "--no-playlist",
        "--newline",
    ]

    if node_runtime_path:
        # Matches `yt-dlp --js-runtimes node:/path/to/node` on the command line.
        # Deno is the default, but as covered in yt-dlp's EJS wiki page, Node
        # works fine as an alternative when you supply the executable path.
        argv += ["--js-runtimes", f"node:{node_runtime_path}"]

    if cookies_file and os.path.exists(cookies_file):
        argv += ["--cookies", cookies_file]

    try:
        from yt_dlp import parse_options

        _, _, _, ydl_opts = parse_options(argv)
        ydl_opts["logger"] = ProgressJSONLogger()
        ydl_opts["progress_hooks"] = [_progress_hook]

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)

        # After post-processing (audio extraction, etc.), yt-dlp updates
        # requested_downloads[*]['filepath'] to point at the final file —
        # this is the documented, stable way to get it, unlike scraping
        # printed output.
        downloads = info.get("requested_downloads") or []
        final_path = None
        for d in downloads:
            final_path = d.get("filepath") or final_path
        if not final_path:
            final_path = info.get("filepath")  # fallback for older yt-dlp versions

        if not final_path or not os.path.exists(final_path):
            return {"ok": False, "error": f"Download finished but final file not found (got: {final_path!r})"}
        return {"ok": True, "path": final_path}

    except Exception as exc:  # noqa: BLE001 - surface everything to Kotlin
        traceback.print_exc()
        return {"ok": False, "error": f"{type(exc).__name__}: {exc}"}


def get_installed_version() -> str:
    return yt_dlp.version.__version__

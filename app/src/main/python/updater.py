"""
Runtime yt-dlp self-update.

Chaquopy installs pip-declared packages (see app/build.gradle.kts `python { pip { ... } }`)
into the app's private files dir at build time and puts that directory on sys.path.
Re-running pip against the same target at runtime is Chaquopy's documented way to update
packages without shipping a new APK — see https://chaquo.com/chaquopy/doc/current/faq.html
("Can I install packages at runtime?"). Confirm the exact API against the Chaquopy version
you're building with, since this has shifted across releases.
"""

import sys
import yt_dlp


def current_version() -> str:
    return yt_dlp.version.__version__


def update_if_needed(target_dir: str) -> dict:
    """Runs `pip install --upgrade --target <app files dir> yt-dlp[default]`.
    Returns {"updated": bool, "old": str, "new": str} or {"updated": False, "error": str}.
    """
    old_version = current_version()
    try:
        from pip._internal.cli.main import main as pip_main

        exit_code = pip_main([
            "install",
            "--upgrade",
            "--target", target_dir,
            "--no-warn-script-location",
            "yt-dlp[default]",
        ])
        if exit_code != 0:
            return {"updated": False, "error": f"pip exited with code {exit_code}"}

        # Force re-import to see the freshly installed version
        for mod_name in list(sys.modules):
            if mod_name == "yt_dlp" or mod_name.startswith("yt_dlp."):
                del sys.modules[mod_name]
        import yt_dlp as fresh
        new_version = fresh.version.__version__

        return {"updated": new_version != old_version, "old": old_version, "new": new_version}
    except Exception as exc:  # noqa: BLE001
        return {"updated": False, "error": f"{type(exc).__name__}: {exc}"}

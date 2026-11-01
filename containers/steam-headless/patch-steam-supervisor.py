"""Allow Valve's launcher to finish runtime extraction and update restarts."""

from pathlib import Path
import sys


def patch(source: str) -> str:
    replacements = (
        (
            "for _ in {1..1200}; do\n    if pgrep -x steam >/dev/null 2>&1; then",
            "# First-run runtime extraction on persistent storage can exceed two minutes.\n"
            "for _ in {1..18000}; do\n    if pgrep -x steam >/dev/null 2>&1; then",
        ),
        (
            "    if pgrep -x steam >/dev/null 2>&1; then\n"
            "        missing_steam_checks=0\n"
            "    else\n",
            "    if pgrep -x steam >/dev/null 2>&1; then\n"
            "        missing_steam_checks=0\n"
            "    elif kill -0 \"${steam_launcher_pid}\" 2>/dev/null; then\n"
            "        # Valve's launcher stays alive while extracting/updating its runtime.\n"
            "        # The Steam binary can disappear temporarily during those steps.\n"
            "        missing_steam_checks=0\n"
            "    else\n",
        ),
    )
    for old, new in replacements:
        if source.count(old) != 1:
            raise ValueError("Upstream Steam supervisor changed; review the startup fix")
        source = source.replace(old, new)
    return source


if __name__ == "__main__":
    target = Path(sys.argv[1])
    target.write_text(patch(target.read_text()))

"""Find a node in a uiautomator dump and print its centre, or its text.

Coordinates are looked up rather than hardcoded because `adb shell screencap`
is downscaled on this device: a tap aimed at a screenshot pixel lands at
roughly double the intended y. On a phone that is how a tap meant for a
settings tile ends up somewhere else entirely.

Usage:
    python3 find_ui_node.py <dump.xml> centre <substring>
    python3 find_ui_node.py <dump.xml> has <substring>
"""

from __future__ import annotations

import pathlib
import re
import sys
import xml.etree.ElementTree as ET

BOUNDS = re.compile(r"\[(\d+),(\d+)]\[(\d+),(\d+)]")


def _nodes(path: pathlib.Path) -> list[ET.Element]:
    return list(ET.fromstring(path.read_text(encoding="utf-8")).iter("node"))


def _matching(path: pathlib.Path, needle: str) -> list[ET.Element]:
    lowered = needle.lower()
    return [
        node
        for node in _nodes(path)
        if lowered in (node.get("text") or "").lower()
        or lowered in (node.get("content-desc") or "").lower()
    ]


def centre(path: pathlib.Path, needle: str) -> int:
    """Prints `x y` for the first node whose text contains [needle]."""
    for node in _matching(path, needle):
        match = BOUNDS.match(node.get("bounds") or "")
        if match is None:
            continue
        left, top, right, bottom = (int(value) for value in match.groups())
        print((left + right) // 2, (top + bottom) // 2)
        return 0
    return 1


def has(path: pathlib.Path, needle: str) -> int:
    """Exits 0 when some node's text contains [needle]."""
    return 0 if _matching(path, needle) else 1


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[2] not in {"centre", "has"}:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    if not path.exists():
        print(f"no such dump: {path}", file=sys.stderr)
        return 2
    return {"centre": centre, "has": has}[sys.argv[2]](path, sys.argv[3])


if __name__ == "__main__":
    sys.exit(main())

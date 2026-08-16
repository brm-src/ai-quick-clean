#!/usr/bin/env python3
"""Bridge the Omarchy overlay to aismell's conservative short-text cleaner."""

from __future__ import annotations

import json
import subprocess
import sys

from aismell_cleaner import clean

MAX_CHARS = 3_000


def clean_payload(text: str) -> dict[str, object]:
    """Return a stable desktop payload without exposing detector internals."""
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    result = clean(text)
    if result.language == "es":
        if result.changes == 1:
            message = "Quité 1 frase de relleno."
        elif result.changes:
            message = f"Quité {result.changes} frases de relleno."
        else:
            message = "No encontré relleno seguro para quitar."
    else:
        if result.changes == 1:
            message = "Removed 1 filler phrase."
        elif result.changes:
            message = f"Removed {result.changes} filler phrases."
        else:
            message = "No safe filler to remove."
    return {
        "ok": True,
        "source": text,
        "text": result.text,
        "changes": result.changes,
        "edits": [{"removed": edit.removed} for edit in result.edits],
        "message": message,
        "language": result.language,
    }


def _read_clipboard() -> str:
    completed = subprocess.run(
        ["wl-paste", "--no-newline"],
        check=False,
        capture_output=True,
        text=True,
        timeout=3,
    )
    return completed.stdout if completed.returncode == 0 else ""


def _read_stdin_text() -> str:
    """Read one record from Quickshell without waiting for pipe EOF."""
    marker = "\x1e"
    chunks: list[str] = []
    while True:
        character = sys.stdin.read(1)
        if not character or character == marker:
            return "".join(chunks)
        chunks.append(character)


def clean_clipboard() -> dict[str, object]:
    return clean_payload(_read_clipboard())


def copy_text(text: str) -> dict[str, object]:
    if not text:
        return {"ok": False, "errorCode": "nothing-to-copy"}
    completed = subprocess.run(
        ["wl-copy"],
        input=text,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=3,
    )
    if completed.returncode:
        return {"ok": False, "errorCode": "clipboard-failed"}
    return {"ok": True}


def main(argv: list[str] | None = None) -> int:
    command = (argv or sys.argv[1:])[:1]
    if command == ["clean-clipboard"]:
        payload = clean_clipboard()
    elif command == ["clean-stdin"]:
        payload = clean_payload(_read_stdin_text())
    elif command == ["copy-stdin"]:
        payload = copy_text(_read_stdin_text())
    else:
        payload = {"ok": False, "errorCode": "invalid-command"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

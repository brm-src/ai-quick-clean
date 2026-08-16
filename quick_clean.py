#!/usr/bin/env python3
"""Bridge from the Omarchy panel to the hosted ai quick clean rewrite service."""

from __future__ import annotations

import json
import subprocess
import sys
from typing import Any

MAX_CHARS = 3_000
REWRITE_URL = "https://aismell-rewrite.brmcl.workers.dev/rewrite"


def _post_rewrite(payload: dict[str, str]) -> dict[str, Any] | None:
    """Call the public service through curl; it works reliably with Workers WAF."""
    try:
        completed = subprocess.run(
            [
                "curl", "--silent", "--show-error", "--fail-with-body", "--max-time", "25",
                "--request", "POST", REWRITE_URL,
                "--header", "Content-Type: application/json",
                "--data-binary", "@-",
            ],
            input=json.dumps(payload, ensure_ascii=False),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode:
        return None
    try:
        data = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def rewrite_payload(text: str) -> dict[str, object]:
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    result = _post_rewrite({"text": text})
    rewritten = result.get("text") if result else None
    changes = result.get("changes") if result else None
    if not isinstance(rewritten, str) or not rewritten.strip() or not isinstance(changes, list):
        return {"ok": False, "errorCode": "rewrite-unavailable"}

    return {
        "ok": True,
        "source": text,
        "text": rewritten,
        "changes": [item for item in changes if isinstance(item, str) and item.strip()][:12],
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
    marker = "\x1e"
    chunks: list[str] = []
    while True:
        character = sys.stdin.read(1)
        if not character or character == marker:
            return "".join(chunks)
        chunks.append(character)


def clipboard_payload() -> dict[str, object]:
    """Hand the panel the clipboard as-is, so opening it needs no extra click."""
    text = _read_clipboard()
    return {"ok": True, "source": text[:MAX_CHARS], "truncated": len(text) > MAX_CHARS}


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
    return {"ok": True} if not completed.returncode else {"ok": False, "errorCode": "clipboard-failed"}


def main(argv: list[str] | None = None) -> int:
    command = (argv or sys.argv[1:])[:1]
    if command == ["read-clipboard"]:
        payload = clipboard_payload()
    elif command == ["rewrite-clipboard"]:
        payload = rewrite_payload(_read_clipboard())
    elif command == ["rewrite-stdin"]:
        payload = rewrite_payload(_read_stdin_text())
    elif command == ["copy-stdin"]:
        payload = copy_text(_read_stdin_text())
    else:
        payload = {"ok": False, "errorCode": "invalid-command"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

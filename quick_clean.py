#!/usr/bin/env python3
"""Bridge the Omarchy panel to aismell's actual local analysis engine."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

MAX_CHARS = 3_000
DEFAULT_ENGINE_HOME = Path.home() / "Developer" / "aismell"


def _engine() -> tuple[Any | None, str | None]:
    """Load the real aismell analyzer, never a second set of guessed rules."""
    engine_home = Path(os.environ.get("AISMELL_HOME", DEFAULT_ENGINE_HOME)).expanduser()
    if engine_home.is_dir() and str(engine_home) not in sys.path:
        sys.path.insert(0, str(engine_home))
    try:
        from aismell.core import analyze
    except (ImportError, SystemExit):
        return None, "engine-missing"
    return analyze, None


def analyze_payload(text: str) -> dict[str, object]:
    """Return actual high-confidence aismell findings for a short editable text."""
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    analyze, error = _engine()
    if error:
        return {"ok": False, "errorCode": error}

    report, language = analyze(text, strict=True, include_segments=False)
    findings = [
        {
            "id": hit.pattern.id,
            "matched": hit.matched,
            "severity": hit.pattern.severity,
            "message": hit.pattern.message,
            "suggestion": hit.pattern.suggestion,
            "line": hit.line,
            "column": hit.col,
        }
        for hit in report.hits
    ]
    count = len(findings)
    if language == "es":
        message = "No vi una señal fuerte en este texto." if not count else f"aismell marcó {count} señal{'es' if count != 1 else ''} para revisar."
    else:
        message = "No strong aismell signal found in this text." if not count else f"aismell found {count} signal{'s' if count != 1 else ''} to review."
    return {
        "ok": True,
        "source": text,
        "language": language,
        "score": round(report.score * 100),
        "findings": findings,
        "message": message,
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
    if command == ["analyze-clipboard"]:
        payload = analyze_payload(_read_clipboard())
    elif command == ["analyze-stdin"]:
        payload = analyze_payload(_read_stdin_text())
    elif command == ["copy-stdin"]:
        payload = copy_text(_read_stdin_text())
    else:
        payload = {"ok": False, "errorCode": "invalid-command"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

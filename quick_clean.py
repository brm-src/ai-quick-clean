#!/usr/bin/env python3
"""Bridge the Omarchy overlay to aismell's conservative short-text cleaner."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from aismell_cleaner import clean

STATE_FILE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "aismell-quick-clean" / "latest.txt"
MAX_CHARS = 12_000


def clean_payload(text: str) -> dict[str, object]:
    """Return a stable desktop payload without exposing detector internals."""
    if not text.strip():
        return {"ok": False, "error": "Copia un texto antes de abrir esto."}
    if len(text) > MAX_CHARS:
        return {"ok": False, "error": "Este plugin es para textos cortos. Usa aismell.me para documentos largos."}

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


def _write_latest(text: str) -> None:
    STATE_FILE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    STATE_FILE.write_text(text, encoding="utf-8")
    STATE_FILE.chmod(0o600)


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
    payload = clean_payload(_read_clipboard())
    if payload.get("ok"):
        _write_latest(str(payload["text"]))
    return payload


def copy_latest() -> dict[str, object]:
    try:
        text = STATE_FILE.read_text(encoding="utf-8")
    except FileNotFoundError:
        return {"ok": False, "error": "Primero limpia un texto."}

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
        return {"ok": False, "error": "No pude copiar el texto limpio."}
    return {"ok": True, "message": "Texto limpio copiado."}


def main(argv: list[str] | None = None) -> int:
    command = (argv or sys.argv[1:])[:1]
    if command == ["clean-clipboard"]:
        payload = clean_clipboard()
    elif command == ["clean-stdin"]:
        payload = clean_payload(_read_stdin_text())
        if payload.get("ok"):
            _write_latest(str(payload["text"]))
    elif command == ["copy-latest"]:
        payload = copy_latest()
    else:
        payload = {"ok": False, "error": "Comando no válido."}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

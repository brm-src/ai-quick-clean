#!/usr/bin/env python3
"""Bridge from the Omarchy panel to the hosted aismell rewrite and bibliography services."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import time
import unicodedata
from functools import lru_cache
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

MAX_CHARS = 3_000
CHECK_MAX_CHARS = 12_000
REWRITE_URL = "https://aismell-rewrite.brmcl.workers.dev/rewrite"
CHECK_URL = "https://aismell-rewrite.brmcl.workers.dev/bibliography"

# In-memory cache: avoids hitting the online service for identical inputs
# within a short window. Keyed by (sha256(text), mode).
_REWRITE_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
CACHE_TTL = 60  # seconds


def _post_json(url: str, payload: dict[str, str], timeout: int = 30) -> dict[str, Any] | None:
    """Call the public service through curl; it works reliably with Workers WAF."""
    try:
        completed = subprocess.run(
            [
                "curl", "--silent", "--show-error", "--fail-with-body", "--max-time", "25",
                "--request", "POST", url,
                "--header", "Content-Type: application/json",
                "--data-binary", "@-",
            ],
            input=json.dumps(payload, ensure_ascii=False),
            capture_output=True,
            text=True,
            timeout=timeout,
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


def _post_rewrite(payload: dict[str, str]) -> dict[str, Any] | None:
    return _post_json(REWRITE_URL, payload)


def _post_check(text: str) -> dict[str, Any] | None:
    return _post_json(CHECK_URL, {"text": text})


def rewrite_payload(text: str, mode: str = "clean") -> dict[str, object]:
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    cache_key = hashlib.sha256(text.encode("utf-8")).hexdigest() + ":" + mode
    now = time.monotonic()
    cached = _REWRITE_CACHE.get(cache_key)
    if cached and (now - cached[0]) < CACHE_TTL:
        return cached[1]

    request_payload = {"text": text}
    if mode == "improve":
        request_payload["mode"] = "improve"
    result = _post_rewrite(request_payload)
    rewritten = result.get("text") if result else None
    changes = result.get("changes") if result else None
    if not isinstance(rewritten, str) or not rewritten.strip() or not isinstance(changes, list):
        outcome = {"ok": False, "errorCode": "rewrite-unavailable"}
    else:
        outcome = {
            "ok": True,
            "source": text,
            "text": rewritten,
            "changes": [item for item in changes if isinstance(item, str) and item.strip()][:12],
        }
    if outcome.get("ok"):
        _REWRITE_CACHE[cache_key] = (now, outcome)
    return outcome


def _normal_tokens(value: str) -> set[str]:
    normalized = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode().lower()
    return {token for token in "".join(character if character.isalnum() else " " for character in normalized).split() if len(token) > 2}


def _overlap(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / max(len(left), len(right))


def _openalex_lookup(entry: dict[str, Any]) -> tuple[str, float, dict[str, Any] | None]:
    identifier = str(entry.get("identifier") or "")
    if identifier.startswith("doi:"):
        params = {"filter": f"doi:https://doi.org/{identifier[4:]}", "per-page": "3"}
    else:
        query = " ".join(filter(None, [str(entry.get("title") or ""), str(entry.get("authorPrefix") or "")]))
        params = {"search": query[:500], "per-page": "3"}
    url = "https://api.openalex.org/works?" + urlencode(params)
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "ai-bibliography-check/1.0"})
    try:
        with urlopen(request, timeout=12) as response:
            payload = json.load(response)
    except Exception:
        return "unavailable", 0.0, None

    candidates = payload.get("results") if isinstance(payload, dict) else []
    ranked = []
    for candidate in candidates or []:
        title = str(candidate.get("title") or "")
        authors = "; ".join(
            str(item.get("author", {}).get("display_name") or "")
            for item in candidate.get("authorships", [])[:2]
        )
        year = candidate.get("publication_year")
        doi = str(candidate.get("doi") or "")
        if identifier.startswith("doi:"):
            score = 1.0 if identifier[4:].lower() in doi.lower() else 0.0
        else:
            score = (
                _overlap(_normal_tokens(str(entry.get("title") or "")), _normal_tokens(title)) * 0.72
                + _overlap(_normal_tokens(str(entry.get("authorPrefix") or "")), _normal_tokens(authors)) * 0.18
                + (0.10 if str(entry.get("year") or "")[:4] == str(year or "")[:4] else 0.0)
            )
        ranked.append((score, {
            "source": "OpenAlex",
            "title": title,
            "author": authors,
            "year": year,
            "doi": doi or None,
            "url": candidate.get("primary_location", {}).get("landing_page_url") or candidate.get("id"),
        }))
    if not ranked:
        return "empty", 0.0, None
    score, match = max(ranked, key=lambda item: item[0])
    return ("found" if score >= 0.72 else "possible" if score >= 0.60 else "not-found"), round(score, 2), match if score >= 0.60 else None


def _merge_local_openalex(report: dict[str, Any]) -> None:
    lookup = report.get("lookup")
    if not isinstance(lookup, dict):
        return
    entries = report.get("entries") or []
    results = lookup.get("results") or []
    for result, entry in zip(results, entries):
        sources = result.get("sources") or []
        openalex = next((source for source in sources if source.get("source") == "OpenAlex"), None)
        if not openalex or openalex.get("status") != "unavailable":
            continue
        status, score, match = _openalex_lookup(entry)
        openalex.update({"status": "responded" if status != "unavailable" else "unavailable", "transport": "local-helper"})
        if status in {"found", "possible"} and (result.get("status") in {"not-found", "unavailable"} or score > float(result.get("score") or 0)):
            result["status"] = status
            result["score"] = score
            result["match"] = match
    lookup["transportFallback"] = "local OpenAlex fallback used when the Worker could not reach OpenAlex"


def check_payload(text: str) -> dict[str, object]:
    if not text.strip():
        return {"ok": False, "errorCode": "empty"}
    if len(text) > CHECK_MAX_CHARS:
        return {"ok": False, "errorCode": "too-long"}

    result = _post_check(text)
    if not result or not isinstance(result.get("score"), int) or not isinstance(result.get("findings"), list):
        return {"ok": False, "errorCode": "check-unavailable"}
    _merge_local_openalex(result)
    return {"ok": True, "report": result}


def _read_clipboard() -> str:
    for command in (
        ["wl-paste", "--primary", "--no-newline"],
        ["wl-paste", "--no-newline"],
    ):
        try:
            completed = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=3,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        if completed.returncode == 0 and completed.stdout:
            return completed.stdout
    return ""


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
    return {"ok": True, "source": text[:CHECK_MAX_CHARS], "truncated": len(text) > CHECK_MAX_CHARS}


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
    elif command == ["rewrite-stdin-improve"]:
        payload = rewrite_payload(_read_stdin_text(), mode="improve")
    elif command == ["check-stdin"]:
        payload = check_payload(_read_stdin_text())
    elif command == ["copy-stdin"]:
        payload = copy_text(_read_stdin_text())
    else:
        payload = {"ok": False, "errorCode": "invalid-command"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())

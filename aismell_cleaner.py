"""The deterministic, conservative cleanup subset from aismell.

This bundled module keeps the Omarchy plugin portable. It does not call a
model, rewrite facts, or send text anywhere. Each edit is kept explicitly so
the caller can show exactly what changed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class CleanEdit:
    removed: str


@dataclass(frozen=True)
class CleanResult:
    text: str
    language: str
    edits: tuple[CleanEdit, ...]

    @property
    def changes(self) -> int:
        return len(self.edits)


_ES_HINTS = re.compile(
    r"\b(que|para|como|pero|porque|según|también|así|este|esta|del|los|las|una|uno|"
    r"hacia|cuando|aunque|entonces|aquí|allí|qué|sí|no|gracias|hola|por favor|"
    r"señor|señora|muy|está|están|estoy|estamos|era|eras|éramos)\b",
    re.IGNORECASE,
)
_EN_HINTS = re.compile(
    r"\b(the|and|of|to|in|that|is|with|for|on|as|by|are|this|from|but|or|"
    r"because|when|where|which|though|thank you|please|sir|madam)\b",
    re.IGNORECASE,
)


def detect_language(text: str) -> str:
    spanish = len(_ES_HINTS.findall(text))
    english = len(_EN_HINTS.findall(text))
    if "¿" in text or "¡" in text:
        spanish += 2
    if re.search(r"[áéíóúüñÁÉÍÓÚÜÑ]", text):
        spanish += 1
    return "es" if spanish >= english else "en"


# These rules only remove framing whose deletion does not alter the claim.
# Discourse markers that may carry contrast or conclusion ("that said",
# "ultimately", "dicho esto") deliberately stay out of this automatic pass.
_RULES: dict[str, tuple[str, ...]] = {
    "es": (
        r"\bcabe mencionar que\s+",
        r"\bes importante (?:notar|señalar|destacar|mencionar) que\s+",
        r"\bvale la pena destacar que\s+",
        r"\ben (?:resumen|síntesis|definitiva),?\s+",
    ),
    "en": (
        r"^\s*(?:here'?s the thing|let'?s be clear)\s*:\s*",
        r"\b(?:it is|it's) worth noting that\s+",
        r"\bit is important to (?:note|mention|highlight) that\s+",
        r"\bin (?:summary|conclusion),?\s+",
        r"\s+i hope this helps!?\s*$",
    ),
}

# Never alter quoted material or structured Markdown. A quick cleaner must be
# boring around text that is likely intentional, literal, or code-like.
_PROTECTED = re.compile(
    r"```[\s\S]*?```|`[^`]*`|^\s*(?:[-+*]|\d+[.)])\s+.*$|^\s*>.*$|"
    r'"[^"\n]*"|“[^”\n]*”|https?://[^\s]+|\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b',
    re.IGNORECASE | re.MULTILINE,
)


def _protect(text: str) -> tuple[str, list[str]]:
    values: list[str] = []

    def replace(match: re.Match[str]) -> str:
        values.append(match.group(0))
        return f"\ue000{len(values) - 1}\ue001"

    return _PROTECTED.sub(replace, text), values


def _restore(text: str, values: list[str]) -> str:
    for index, value in enumerate(values):
        text = text.replace(f"\ue000{index}\ue001", value)
    return text


def _tidy(text: str) -> str:
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"(^|[.!?]\s+|\n+)([a-záéíóúüñ])", lambda match: match.group(1) + match.group(2).upper(), text)
    return text.strip()


def clean(text: str, language: str | None = None) -> CleanResult:
    """Remove only high-confidence filler while preserving the user's text."""
    detected = language or detect_language(text)
    detected = detected if detected in _RULES else "en"
    masked, protected = _protect(text)
    edits: list[CleanEdit] = []

    for pattern in _RULES[detected]:
        def remove(match: re.Match[str]) -> str:
            edits.append(CleanEdit(removed=match.group(0).strip(" \t,.:;!?")))
            return ""

        masked = re.sub(pattern, remove, masked, flags=re.IGNORECASE)

    return CleanResult(text=_restore(_tidy(masked), protected), language=detected, edits=tuple(edits))

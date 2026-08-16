"""Contract tests for the aismell quick-clean desktop helper."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from quick_clean import clean_payload


def test_returns_cleaned_text_and_a_concise_change_summary():
    payload = clean_payload("Hola, cabe mencionar que ya envié el archivo.")

    assert payload == {
        "ok": True,
        "text": "Hola, ya envié el archivo.",
        "changes": 1,
        "message": "Quité 1 frase de relleno.",
    }

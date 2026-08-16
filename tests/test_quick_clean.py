"""Contract tests for the aismell quick-clean desktop helper."""

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import quick_clean
from aismell_cleaner import clean
from quick_clean import clean_payload, main


def test_returns_cleaned_text_and_a_concise_change_summary():
    payload = clean_payload("Hola, cabe mencionar que ya envié el archivo.")

    assert payload == {
        "ok": True,
        "text": "Hola, ya envié el archivo.",
        "source": "Hola, cabe mencionar que ya envié el archivo.",
        "changes": 1,
        "edits": [{"removed": "cabe mencionar que"}],
        "message": "Quité 1 frase de relleno.",
        "language": "es",
    }


def test_returns_an_english_summary_for_english_text():
    payload = clean_payload("It is important to note that the file is ready. In conclusion, thanks.")

    assert payload == {
        "ok": True,
        "text": "The file is ready. Thanks.",
        "source": "It is important to note that the file is ready. In conclusion, thanks.",
        "changes": 2,
        "edits": [
            {"removed": "It is important to note that"},
            {"removed": "In conclusion"},
        ],
        "message": "Removed 2 filler phrases.",
        "language": "en",
    }


def test_cleans_edited_text_received_on_standard_input(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO("Here's the thing: the file is ready.\x1e"))

    assert main(["clean-stdin"]) == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload["source"] == "Here's the thing: the file is ready."
    assert payload["text"] == "The file is ready."


def test_explains_the_exact_safe_removal_without_touching_quotes_or_markdown():
    result = clean('"In conclusion, keep this."\n- In conclusion, keep this too.\nIt is important to note that the file is ready.')

    assert result.text == '"In conclusion, keep this."\n- In conclusion, keep this too.\nThe file is ready.'
    assert [edit.removed for edit in result.edits] == ["It is important to note that"]


def test_cleaning_edited_text_never_writes_a_state_file(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO("It is important to note that the file is ready.\x1e"))

    assert main(["clean-stdin"]) == 0

    assert not hasattr(quick_clean, "STATE_FILE")
    payload = json.loads(capsys.readouterr().out)
    assert payload["text"] == "The file is ready."

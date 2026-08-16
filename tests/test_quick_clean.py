"""Contract tests for the aismell quick-review desktop helper."""

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import quick_clean
from quick_clean import analyze_payload, main


def test_uses_aismells_actual_span_and_editorial_suggestion():
    payload = analyze_payload("It is important to note that the file is ready.")

    assert payload["ok"] is True
    assert payload["source"] == "It is important to note that the file is ready."
    assert payload["language"] == "en"
    assert payload["findings"] == [{
        "id": "en.important_to_note",
        "matched": "It is important to note",
        "severity": 3,
        "message": '"important to note" — meta-announcement',
        "suggestion": "delete and state the point",
        "line": 1,
        "column": 0,
    }]


def test_reports_multiple_real_aismell_signals_without_rewriting_the_text():
    source = "No es solo una herramienta, sino que también es un punto clave."
    payload = analyze_payload(source)

    assert payload["ok"] is True
    assert payload["source"] == source
    assert payload["findings"][0]["id"] == "es.no_solo_sino"
    assert payload["findings"][0]["suggestion"] == "di la idea positiva sin el contraste de relleno"


def test_analyzes_edited_text_received_on_standard_input(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO("It is important to note that the file is ready.\x1e"))

    assert main(["analyze-stdin"]) == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload["source"] == "It is important to note that the file is ready."
    assert payload["findings"][0]["id"] == "en.important_to_note"


def test_keeps_text_in_memory_without_a_state_file():
    assert not hasattr(quick_clean, "STATE_FILE")

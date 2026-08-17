"""Contract tests for the portable aismell rewrite helper."""

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import quick_clean
from quick_clean import main, rewrite_payload


def test_sends_the_edited_text_to_the_public_aismell_rewrite_service(monkeypatch):
    sent = {}

    def fake_post(payload):
        sent.update(payload)
        return {"text": "The report is ready.", "changes": ["Removed filler."]}

    monkeypatch.setattr(quick_clean, "_post_rewrite", fake_post)
    source = "It is important to note that the report is ready."

    payload = rewrite_payload(source)

    assert sent == {"text": source}
    assert payload == {
        "ok": True,
        "source": source,
        "text": "The report is ready.",
        "changes": ["Removed filler."],
    }


def test_sends_improve_mode_to_the_public_service(monkeypatch):
    sent = {}

    def fake_post(payload):
        sent.update(payload)
        return {"text": "The report is ready.", "changes": ["Cut boilerplate."]}

    monkeypatch.setattr(quick_clean, "_post_rewrite", fake_post)

    assert rewrite_payload("It is important to note that the report is ready.", mode="improve")["ok"] is True
    assert sent == {"text": "It is important to note that the report is ready.", "mode": "improve"}


def test_does_not_claim_success_when_the_rewrite_service_is_unavailable(monkeypatch):
    monkeypatch.setattr(quick_clean, "_post_rewrite", lambda payload: None)

    assert rewrite_payload("The report is ready.") == {"ok": False, "errorCode": "rewrite-unavailable"}


def test_rewrites_edited_text_received_on_standard_input(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO("It is important to note that the file is ready.\x1e"))
    monkeypatch.setattr(quick_clean, "_post_rewrite", lambda payload: {"text": "The file is ready.", "changes": ["Removed filler."]})

    assert main(["rewrite-stdin"]) == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload["text"] == "The file is ready."
    assert payload["changes"] == ["Removed filler."]


def test_keeps_text_in_memory_without_a_state_file():
    assert not hasattr(quick_clean, "STATE_FILE")


def test_hands_the_panel_the_clipboard_without_cleaning_it_yet(monkeypatch, capsys):
    monkeypatch.setattr(quick_clean, "_read_clipboard", lambda: "It is important to note that this is a draft.")
    monkeypatch.setattr(
        quick_clean,
        "_post_rewrite",
        lambda payload: (_ for _ in ()).throw(AssertionError("opening the panel must not call the service")),
    )

    assert main(["read-clipboard"]) == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload == {
        "ok": True,
        "source": "It is important to note that this is a draft.",
        "truncated": False,
    }

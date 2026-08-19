"""Contract tests for the portable aismell rewrite and bibliography helper."""

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import quick_clean
from quick_clean import check_payload, main, rewrite_payload

BIBLIOGRAPHY = "[1] García, M. (2024). Manual de investigación. https://doi.org/10.1234/demo"


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


def test_posts_bibliography_only_after_local_validation(monkeypatch):
    sent = {}

    def fake_post(text):
        sent["text"] = text
        return {"score": 100, "findings": [], "entryCount": 1}

    monkeypatch.setattr(quick_clean, "_post_check", fake_post)

    assert check_payload(BIBLIOGRAPHY) == {
        "ok": True,
        "report": {"score": 100, "findings": [], "entryCount": 1},
    }
    assert sent == {"text": BIBLIOGRAPHY}


def test_rejects_empty_and_oversized_bibliography_without_network(monkeypatch):
    def boom(text):
        raise AssertionError("network call")

    monkeypatch.setattr(quick_clean, "_post_check", boom)

    assert check_payload(" ") == {"ok": False, "errorCode": "empty"}
    assert check_payload("x" * 12_001) == {"ok": False, "errorCode": "too-long"}


def test_does_not_claim_success_for_bad_check_response(monkeypatch):
    monkeypatch.setattr(quick_clean, "_post_check", lambda text: {"error": "unavailable"})

    assert check_payload(BIBLIOGRAPHY) == {"ok": False, "errorCode": "check-unavailable"}


def test_uses_local_openalex_fallback_when_worker_cannot_reach_it(monkeypatch):
    report = {
        "score": 100,
        "findings": [],
        "entries": [{"number": 1, "title": "Manual de investigación", "authorPrefix": "García, M.", "year": "2024", "identifier": "doi:10.1234/demo"}],
        "lookup": {
            "results": [{
                "entry": 1,
                "status": "found",
                "score": 0.9,
                "sources": [{"source": "Crossref", "status": "responded"}, {"source": "OpenAlex", "status": "unavailable"}],
                "match": {"source": "Crossref", "title": "Manual de investigación"},
            }],
        },
    }
    monkeypatch.setattr(quick_clean, "_post_check", lambda text: report)
    monkeypatch.setattr(
        quick_clean,
        "_openalex_lookup",
        lambda entry: ("found", 1.0, {"source": "OpenAlex", "title": "Manual de investigación"}),
    )

    payload = check_payload(BIBLIOGRAPHY)

    result = payload["report"]["lookup"]["results"][0]
    assert result["match"]["source"] == "OpenAlex"
    assert result["sources"][1]["status"] == "responded"
    assert result["sources"][1]["transport"] == "local-helper"
    assert "transportFallback" in payload["report"]["lookup"]


def test_checks_bibliography_received_on_standard_input(monkeypatch, capsys):
    monkeypatch.setattr(sys, "stdin", io.StringIO(BIBLIOGRAPHY + "\x1e"))
    monkeypatch.setattr(quick_clean, "_post_check", lambda text: {"score": 88, "findings": [], "entryCount": 1})

    assert main(["check-stdin"]) == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload["report"]["score"] == 88

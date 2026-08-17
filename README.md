# ai quick clean

<p align="center">
  <a href="https://www.ko-fi.com/brmcl"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" /></a>
</p>

[Español](README.es.md)

![ai quick clean preview](preview.png)

A bilingual Omarchy / Quickshell panel for making short AI-drafted messages sound more direct and human. It keeps the original editable, shows the proposed version beside it, reports the edits, and lets you copy only when you approve them.

It is deliberately not an AI detector bypass and it does not promise that a rewrite will evade any detector. It is a writing editor.

## What it does

- Works with English and Spanish messages, emails, and short paragraphs up to 3,000 characters.
- Reads the Wayland primary selection first, then the regular clipboard, to prefill the editor.
- `clean` removes only high-confidence filler and leaves direct wording alone.
- `improve` makes a more visible edit: cuts ceremonial openings, institutional boilerplate, repetition, abstract phrasing, and inflated adjectives while preserving facts and intent.
- Shows the original and proposed text side by side.
- Shows an indeterminate progress bar while the online editor is working.
- Reports how many edits were returned and lists the first three explanations.
- Never replaces the focused application's text automatically. You must press `copy`.

## Install

```bash
omarchy plugin add https://github.com/brm-src/ai-quick-clean.git --enable --yes
```

No administrator privileges are required. The plugin needs Omarchy/Hyprland, Quickshell, Python 3, `curl`, `wl-paste`, and `wl-copy`.

The optional `Super + Shift + S` shortcut is configured separately:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-quick-clean/configure-shortcut.sh
```

Remove only that shortcut with:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-quick-clean/configure-shortcut.sh --remove
```

Remove the plugin with:

```bash
omarchy plugin remove io.github.brm-src.ai-quick-clean --yes
```

## Use

1. Copy or select a short draft, then open **ai quick clean** from the bar.
2. Edit the text if needed.
3. Choose `clean` for a conservative pass or `improve` for a more noticeable humanizing edit.
4. Wait for the progress bar to finish and read the change explanations.
5. Compare both columns.
6. Press `copy` only if you want the proposed version in the clipboard.

Press `Escape`, `Super + W`, or click outside the card to close it. The `powered by: aismell.me` footer opens the project site.

## Privacy and data flow

See [PRIVACY.md](PRIVACY.md) for the full data-flow notes.

- Opening the panel only reads the primary selection or clipboard to prefill the editor.
- The plugin does not write source text, rewritten text, or clipboard contents to disk.
- Text is sent over HTTPS to the public aismell rewrite Worker only after you press `clean` or `improve`.
- The Worker runs the aismell analyzer and Cloudflare Workers AI. It has no application database, KV namespace, R2 bucket, Durable Object, or submitted-text store.
- Responses are sent with `Cache-Control: no-store`.
- Cloudflare still processes the request as an infrastructure provider. Do not send passwords, private keys, confidential client material, or anything that must remain offline.
- The plugin asks for no API key, does not install packages, does not request elevated privileges, and does not run downloaded code.

## How it works

1. `quick_clean.py` reads the selected text locally and enforces the 3,000-character limit.
2. The Worker sends the text to the aismell analyzer for language and signal evidence.
3. The Worker chooses the conservative `clean` prompt or the stronger `improve` prompt.
4. Workers AI returns one proposed text and short change explanations as JSON.
5. The panel keeps the response in memory and never copies it until you press `copy`.

## Limitations

- The service requires an internet connection.
- A conservative clean may correctly return no changes.
- `improve` is a proposal, not an authority. Read it before copying.
- The service accepts English and Spanish only.
- Text is sent to an online service; this is not an offline or confidential editor.

## Development checks

Run these from the repository root:

```bash
python3 -m pytest tests -q
python3 -m py_compile quick_clean.py
bash -n configure-shortcut.sh
qmllint -I /usr/share/omarchy/shell BarButton.qml QuickClean.qml
omarchy plugin validate .
git diff --check
```

## License

MIT. See [LICENSE](LICENSE).

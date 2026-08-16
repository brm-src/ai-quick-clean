# aismell quick clean

![aismell quick clean preview](preview.png)

A small Omarchy shortcut that brings aismell's real local review into the place where you write.

`super + shift + s` opens a compact editor. Paste, type, or load the clipboard; aismell shows the exact high-confidence signals it sees, why it flagged them, and its editorial suggestion. You make the edit — then copy your text when it sounds like you.

## What it does

- Works with short English and Spanish messages, emails, and paragraphs (up to 3,000 characters).
- Calls aismell's actual high-confidence detector, including its current pattern catalog.
- Shows the matched phrase, why it was flagged, and the engine's editorial suggestion.
- Keeps the text editable: review, rewrite in your own words, then copy the result.

It is not a generative rewriter. That is deliberate: aismell points to concrete signals; it does not invent a replacement and pretend it knows your intent.

## Use

1. Copy text, or open it empty and paste/type directly.
2. Press `super + shift + s` and choose **review text**.
3. Use the signals and suggestions on the right to revise in the editor.
4. Choose **copy edited text** when you are ready.

`escape` closes the window. `ctrl + enter` runs a new review.

## Local installation

The plugin needs Omarchy/Hyprland, `wl-paste`, `wl-copy`, and the local aismell engine. It looks for `~/Developer/aismell` by default; set `AISMELL_HOME` if your checkout is elsewhere. aismell requires Python 3.9+ and PyYAML. No API key or network connection is used.

```bash
omarchy plugin install https://github.com/brm-src/aismell-quick-clean
```

It registers `super + shift + s`. It does not use `sudo`, install packages, or send text to a service: cleanup happens on your machine.

To remove only the shortcut:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.aismell-quick-clean/setup.sh --remove
```

## Development checks

```bash
/usr/bin/python3 -m pytest tests -q
python3 -m py_compile quick_clean.py
qmllint -I /usr/share/omarchy/shell QuickClean.qml
omarchy plugin validate .
```

## Privacy

The plugin reads text from the clipboard only when you choose **review clipboard**. It runs aismell locally, does not send text over the network, and does not save it to disk. Your edited text is copied only when you choose **copy edited text**.

## Español

Funciona con mensajes, correos y párrafos cortos en español e inglés. Usa el motor local de aismell para mostrar señales reales, la frase marcada y una sugerencia concreta. No reescribe ni envía el texto a una API: tú editas el texto y eliges cuándo copiarlo.

## License

MIT.

# aismell quick clean

![aismell quick clean preview](preview.png)

A small Omarchy shortcut for cleaning the text you just copied — without turning it into something else.

`super + shift + s` opens a compact editor. Paste, type, or load the clipboard on the left; the conservative proposal appears on the right. It lists the exact phrases it proposes to remove. Nothing replaces your clipboard until you choose **replace clipboard**.

## What it does

- Works with short English and Spanish messages, emails, and paragraphs (up to 3,000 characters).
- Removes only high-confidence framing; discourse that can carry meaning stays intact.
- Preserves names, dates, links, quotes, code, Markdown lists, and blockquotes.
- Shows the exact phrases proposed for removal and keeps the clipboard untouched until you decide.

It is not a generative rewriter and it does not score your writing. If it cannot make a safe edit, it leaves the text alone.

## Use

1. Copy text, or open it empty and paste/type directly.
2. Press `super + shift + s` and choose **clean text**.
3. Inspect the exact removals and the proposal, then select **replace clipboard** only if you want it.

`escape` closes the window. `ctrl + enter` runs a new cleanup pass.

## Local installation

The plugin needs Omarchy/Hyprland, `wl-paste`, and `wl-copy`. Its conservative cleanup engine is bundled, so it runs locally without a Python package, API key, or network connection.

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

The plugin reads text from the clipboard only when you choose **use clipboard**. It processes the text locally, does not send it over the network, and does not save it to disk. The result remains in the open review until you explicitly replace the clipboard.

## Español

Funciona con mensajes, correos y párrafos cortos en español e inglés. Quita relleno seguro sin reescribir el contenido ni enviar el texto a una API. Copia un texto y usa `super + shift + s`; compara ambas versiones y elige **reemplazar portapapeles** solo si te sirve.

## License

MIT.

# aismell quick clean

![aismell quick clean preview](preview.png)

A small Omarchy shortcut for cleaning the text you just copied — without turning it into something else.

`super + shift + s` opens a compact review: your original clipboard text is on the left and the safe cleanup is on the right. Nothing replaces your clipboard until you choose **replace clipboard**.

## What it does

- Works with short English and Spanish messages, emails, and paragraphs.
- Removes empty framing, inflated introductions, and generic closers only when the edit is safe.
- Preserves tone, names, dates, links, quotes, code, and lists.
- Shows its summary and controls in the language of the text after cleaning.

It is not a generative rewriter and it does not score your writing. If it cannot make a safe edit, it leaves the text alone.

## Use

1. Copy text.
2. Press `super + shift + s`.
3. Compare the original and cleaned version, then select **replace clipboard** only if you want it.

`escape` closes the window. `ctrl + enter` copies the result.

## Local installation

The plugin needs Omarchy/Hyprland, `wl-paste`, `wl-copy`, and a local copy of the [aismell](https://aismell.me) engine.

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

The plugin reads text from the clipboard. The cleaned result is temporarily saved at `~/.local/state/aismell-quick-clean/latest.txt` with user-only permissions so the **copy clean** button can write it back to the clipboard. It is replaced every time you clean text.

## Español

Funciona con mensajes, correos y párrafos cortos en español e inglés. Quita relleno seguro sin reescribir el contenido ni enviar el texto a una API. Copia un texto y usa `super + shift + s`; compara ambas versiones y elige **reemplazar portapapeles** solo si te sirve.

## License

MIT.

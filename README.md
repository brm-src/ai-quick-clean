# ai quick clean

![ai quick clean preview](preview.png)

An Omarchy panel for cleaning short text drafted with ai tools. If you ask Claude, ChatGPT, or another assistant to write an email, message, or paragraph for you, ai quick clean removes the marks that make it read like ai: stock phrasing, repeated formulas, generic conclusions, and inflated wording. It preserves the actual message, names, links, dates, numbers, quotations, code, and lists.

Open it from the bar button or with `super + shift + s`. The panel loads your clipboard into the editor, but nothing is rewritten until you press **clean**. You can edit the text first, compare the cleaned version, and copy it only if it still sounds like you.

## Examples

- You ask ChatGPT to draft a work email. The message is right, but it says “I hope this message finds you well”, “it is important to note”, or “in conclusion”. ai quick clean trims that filler.
- You ask Claude to polish a Spanish reply. It comes back correct but too formal, with phrases like “es importante señalar que” or “no solo X, sino también Y”. The plugin makes it more direct without changing the meaning.
- You have a short paragraph that sounds overproduced. The plugin gives you a cleaner version, then you decide whether to copy it.

## What it does

- Cleans short English and Spanish messages, emails, and paragraphs, up to 3,000 characters.
- Removes ai-sounding filler such as “it is important to note”, “not just X, but Y”, generic conclusions, and inflated wording.
- Keeps the original editable on the left and shows the cleaned version on the right.
- Copies the cleaned version only when you press **copy**.
- Does not try to evade AI detectors. It is a writing cleanup tool.

## Use

1. Copy a text, or open the panel and paste/type directly.
2. Press **clean**.
3. Compare the cleaned version on the right.
4. Press **copy** only if you want that version in your clipboard.

`escape`, `super + w`, or clicking outside the card closes the panel. `ctrl + enter` runs the cleanup.

## How it works

1. The local Omarchy plugin reads the clipboard with `wl-paste` only to prefill the editor.
2. When you press **clean**, the helper sends the current editor text to the online rewrite service.
3. The rewrite service uses the same detector behind [aismell.me](https://aismell.me) for English and Spanish signals.
4. Those signals guide Workers AI (`@cf/meta/llama-4-scout-17b-16e-instruct`) to make a conservative rewrite.
5. The Worker returns JSON with the cleaned text and a short list of changes. The plugin keeps that in memory and shows it in the panel.

## Storage and privacy

ai quick clean does **not** store your text.

- The plugin does not write the source text, cleaned text, or clipboard contents to disk.
- The backend has no database, KV, R2 bucket, Durable Object, or file storage for submitted text.
- Responses use `Cache-Control: no-store`.
- The text is sent over the network to Cloudflare Workers / Workers AI to produce the rewrite, so do not use it for passwords, private keys, client-confidential material, or anything you would not send to an online writing tool.

## Installation

```bash
omarchy plugin install https://github.com/brm-src/ai-quick-clean
```

It registers `super + shift + s` and adds a bar button. It does not use `sudo` or install packages. It needs Omarchy/Hyprland, `curl`, `wl-paste`, and `wl-copy`.

To remove only the shortcut:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-quick-clean/setup.sh --remove
```

## Development checks

```bash
/usr/bin/python3 -m pytest tests -q
python3 -m py_compile quick_clean.py
qmllint -I /usr/share/omarchy/shell BarButton.qml QuickClean.qml
omarchy plugin validate .
```

## Español

Panel de Omarchy para quitar la palabrería de IA a textos cortos. Si le pides a Claude, ChatGPT u otro asistente que redacte un correo, mensaje o párrafo por ti, ai quick clean limpia las marcas típicas de ese texto: frases de trámite, fórmulas repetidas, conclusiones genéricas y adjetivos de más. Conserva el mensaje, nombres, links, fechas, números, citas, código y listas.

Ejemplos:

- Le pides a ChatGPT un correo de trabajo. El contenido sirve, pero viene con “espero que te encuentres bien”, “es importante señalar que” o un cierre inflado. El plugin recorta ese relleno.
- Le pides a Claude que mejore una respuesta. Queda correcta, pero demasiado formal o robótica. El plugin la vuelve más directa sin cambiar el sentido.
- Tienes un párrafo corto que suena producido de más. El plugin propone una versión limpia y tú decides si copiarla.

Abres desde la barra o con `super + shift + s`, editas si hace falta, presionas **limpiar**, comparas la versión limpia y solo entonces decides si copiarla.

El texto se envía al servicio online de reescritura para generar la propuesta. Ese servicio usa el detector de [aismell.me](https://aismell.me), pero ai quick clean no almacena el texto: el plugin no lo escribe en disco y el backend no tiene base de datos ni almacenamiento de envíos. No lo uses con secretos ni material confidencial.

## License

MIT.

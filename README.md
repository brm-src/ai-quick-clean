# aismell quick clean

![Vista previa de aismell quick clean](preview.png)

Un atajo pequeño para limpiar el texto que acabas de copiar, sin convertirlo en otra cosa.

`super + shift + s` abre una capa sobre Omarchy, lee el portapapeles, elimina relleno seguro y deja una versión lista para copiar.

## Para qué sirve

- Mensajes, correos y párrafos cortos que se sienten inflados o mecánicos.
- Quitar frases de relleno, introducciones grandilocuentes y cierres genéricos que no aportan.
- Conservar el tono, los nombres, fechas, enlaces, citas, código y listas.

No es un reescritor generativo ni asigna una nota a tu texto. Si no encuentra una mejora segura, lo deja intacto.

## Uso

1. Copia el texto.
2. Presiona `super + shift + s`.
3. Revisa el resultado y pulsa **copiar limpio**.

`escape` cierra la ventana. `ctrl + enter` copia el resultado.

## Instalación local

El plugin requiere Omarchy/Hyprland, `wl-paste`, `wl-copy` y una copia local del motor [aismell](https://aismell.me).

```bash
omarchy plugin install https://github.com/brm-src/aismell-quick-clean
```

La instalación registra el atajo `super + shift + s`. No usa `sudo`, no instala paquetes y no envía tu texto a ningún servicio: el procesamiento ocurre en tu equipo.

Para quitar solo el atajo:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.aismell-quick-clean/setup.sh --remove
```

## Desarrollo y comprobación

```bash
/usr/bin/python3 -m pytest tests -q
python3 -m py_compile quick_clean.py
qmllint -I /usr/share/omarchy/shell QuickClean.qml
omarchy plugin validate .
```

## Privacidad

El texto se lee desde el portapapeles y el resultado temporal se guarda en `~/.local/state/aismell-quick-clean/latest.txt`, con permisos de usuario. Se reemplaza cada vez que limpias un texto y sirve únicamente para el botón **copiar limpio**.

## Licencia

MIT.

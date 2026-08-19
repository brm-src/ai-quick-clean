# ai quick clean

<p align="center">
  <a href="https://www.ko-fi.com/brmcl"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" /></a>
</p>

[English](README.md)

![Vista previa de ai quick clean](preview.png)

Panel bilingüe de Omarchy / Quickshell para limpiar textos escritos con ia, mejorar la redacción y revisar bibliografías. Conserva el original editable, muestra la propuesta al lado, informa qué cambió y solo copia cuando tú lo apruebas.

No es una herramienta para evadir detectores de ia ni promete que una reescritura evite ningún detector. Es un editor de texto.

## Qué hace

- Funciona con mensajes, correos y párrafos cortos en español e inglés, hasta 3.000 caracteres (12.000 para bibliografías).
- Lee primero la selección primaria de Wayland y luego el portapapeles normal para cargar el texto.
- Tres modos:
  - **limpiar** — quita relleno de ia y mejora la redacción en una sola pasada.
  - **mejorar** — edición más visible: recorta saludos ceremoniales, lenguaje institucional, repeticiones, frases abstractas y adjetivos inflados, sin cambiar los hechos ni la intención.
  - **bibliografía** — revisa una bibliografía pegada contra Crossref y OpenAlex: busca coincidencias exactas por DOI, consultas por título/autor/año, detecta duplicados y problemas de estructura, y puntúa la lista.
- Muestra el texto original y la propuesta lado a lado en limpiar/mejorar; editor único + resultados en bibliografía.
- Muestra una barra de progreso indeterminada mientras trabaja el servicio online.
- Informa cuántos cambios devolvió y muestra las tres primeras explicaciones.
- Nunca reemplaza automáticamente el texto de la aplicación activa. Debes presionar `copiar`.

## Instalación

```bash
omarchy plugin add https://github.com/brm-src/ai-quick-clean.git --enable --yes
```

No se requieren privilegios de administrador. El plugin necesita Omarchy/Hyprland, Quickshell, Python 3, `curl`, `wl-paste` y `wl-copy`.

El atajo opcional `Super + Shift + S` se configura por separado:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-quick-clean/configure-shortcut.sh
```

Para quitar solo el atajo:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-quick-clean/configure-shortcut.sh --remove
```

Para quitar el plugin:

```bash
omarchy plugin remove io.github.brm-src.ai-quick-clean --yes
```

## Uso

1. Copia o selecciona un borrador corto y abre **ai quick clean** desde la barra.
2. Elige el modo arriba: **limpiar**, **mejorar**, o **bibliografía**.
3. Edita el texto si hace falta.
4. Presiona el botón de acción del modo elegido (`limpiar` / `mejorar` / `revisar`).
5. Espera a que termine la barra de progreso y lee las explicaciones o el informe de bibliografía.
6. En limpiar/mejorar: compara ambas columnas y presiona `copiar` solo si quieres la propuesta en el portapapeles.

Presiona `Escape`, `Super + W` o haz clic fuera de la tarjeta para cerrar. El pie `powered by: aismell.me` abre el sitio del proyecto.

## Privacidad y flujo de datos

Consulta [PRIVACY.md](PRIVACY.md) para ver el flujo completo de datos.

- Al abrir el panel solo lee la selección primaria o el portapapeles para cargar el editor.
- El plugin no escribe en disco el texto original, el texto reescrito ni el contenido del portapapeles.
- El texto se envía por HTTPS al Worker público de aismell solo después de presionar un botón de acción.
- El Worker ejecuta el analizador de aismell y Cloudflare Workers AI. No tiene base de datos de aplicación, KV, R2, Durable Objects ni almacenamiento de envíos.
- Las respuestas se envían con `Cache-Control: no-store`.
- Cloudflare procesa la solicitud como proveedor de infraestructura. No envíes contraseñas, claves privadas, material confidencial de clientes ni contenido que deba permanecer offline.
- El plugin no pide claves de API, no instala paquetes, no solicita elevación y no ejecuta código descargado.

## Cómo funciona

### Limpiar / Mejorar
1. `quick_clean.py` lee localmente el texto seleccionado y aplica el límite de 3.000 caracteres.
2. El Worker envía el texto al analizador de aismell para obtener idioma y señales.
3. El Worker elige el prompt conservador de `clean` o el prompt más fuerte de `improve`.
4. Workers AI devuelve una propuesta y explicaciones breves en JSON.
5. El panel mantiene la respuesta en memoria y no la copia hasta que presionas `copiar`.

### Bibliografía
1. `quick_clean.py` lee localmente el texto pegado y aplica el límite de 12.000 caracteres.
2. El Worker parsea entradas y consulta Crossref REST y OpenAlex Works (por DOI exacto o título+autor+año).
3. Un fallback local de OpenAlex se ejecuta si el Worker no alcanza las APIs externas.
4. Resultados: puntuación 0-100, cuenta de entradas, hallazgos, estado por entrada y enlaces a Google Scholar.
5. El panel muestra el informe; puedes clicar el enlace Scholar de una entrada para abrir la búsqueda.

## Limitaciones

- El servicio necesita conexión a Internet.
- El modo conservador puede devolver correctamente cero cambios.
- `mejorar` es una propuesta, no una autoridad. Léela antes de copiarla.
- La búsqueda bibliográfica depende de APIs externas (Crossref, OpenAlex); problemas de red pueden reducir cobertura.
- El servicio acepta solo español e inglés.
- El texto se envía a un servicio online; no es un editor offline ni confidencial.

## Comprobaciones de desarrollo

Ejecuta desde la raíz del repositorio:

```bash
python3 -m pytest tests -q
python3 -m py_compile quick_clean.py
bash -n configure-shortcut.sh
qmllint -I /usr/share/omarchy/shell BarButton.qml QuickClean.qml
omarchy plugin validate .
git diff --check
```

## Licencia

MIT. Consulta [LICENSE](LICENSE).
#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -f "$config_home/hypr/hyprland.lua" ]]; then
  bindings_file="$config_home/hypr/bindings.lua"
  begin="-- aismell quick clean: begin"
  end="-- aismell quick clean: end"
  binding="o.bind(\"SUPER + SHIFT + S\", \"aismell quick clean\", \"omarchy-shell shell summon io.github.brm-src.aismell-quick-clean '{}'\")"
else
  bindings_file="$config_home/hypr/bindings.conf"
  begin="# aismell quick clean: begin"
  end="# aismell quick clean: end"
  binding="bindd = SUPER SHIFT, S, aismell quick clean, exec, omarchy-shell shell summon io.github.brm-src.aismell-quick-clean '{}'"
fi

python3 - "$bindings_file" "$begin" "$end" "$binding" "${1:-}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
begin, end, binding, mode = sys.argv[2:]
text = path.read_text(encoding="utf-8") if path.exists() else ""
block = "\n".join([begin, binding, end, ""])
pattern = re.compile(re.escape(begin) + r"\n.*?" + re.escape(end) + r"\n?", re.DOTALL)
updated = pattern.sub("", text) if mode == "--remove" else (pattern.sub(block, text) if pattern.search(text) else text.rstrip("\n") + ("\n" if text else "") + block)
path.parent.mkdir(parents=True, exist_ok=True)
temporary = path.with_name(path.name + ".aismell-quick-clean.tmp")
temporary.write_text(updated, encoding="utf-8")
temporary.replace(path)
PY

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

if [[ "${1:-}" == "--remove" ]]; then
  printf 'Atajo eliminado.\n'
else
  printf 'Listo: Super + Shift + S.\n'
fi

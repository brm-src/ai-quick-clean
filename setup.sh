#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -f "$config_home/hypr/hyprland.lua" ]]; then
  bindings_file="$config_home/hypr/bindings.lua"
  begin="-- ai quick clean: begin"
  end="-- ai quick clean: end"
  old_begin="-- aismell quick clean: begin"
  old_end="-- aismell quick clean: end"
  binding="o.bind(\"SUPER + SHIFT + S\", \"ai quick clean\", \"omarchy-shell shell summon io.github.brm-src.ai-quick-clean '{}'\")"
else
  bindings_file="$config_home/hypr/bindings.conf"
  begin="# ai quick clean: begin"
  end="# ai quick clean: end"
  old_begin="# aismell quick clean: begin"
  old_end="# aismell quick clean: end"
  binding="bindd = SUPER SHIFT, S, ai quick clean, exec, omarchy-shell shell summon io.github.brm-src.ai-quick-clean '{}'"
fi

python3 - "$bindings_file" "$begin" "$end" "$old_begin" "$old_end" "$binding" "${1:-}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
begin, end, old_begin, old_end, binding, mode = sys.argv[2:]
text = path.read_text(encoding="utf-8") if path.exists() else ""
block = "\n".join([begin, binding, end, ""])
patterns = [
    re.compile(re.escape(begin) + r"\n.*?" + re.escape(end) + r"\n?", re.DOTALL),
    re.compile(re.escape(old_begin) + r"\n.*?" + re.escape(old_end) + r"\n?", re.DOTALL),
]
updated = text
for pattern in patterns:
    updated = pattern.sub("", updated)
if mode != "--remove":
    updated = updated.rstrip("\n") + ("\n" if updated else "") + block
path.parent.mkdir(parents=True, exist_ok=True)
temporary = path.with_name(path.name + ".ai-quick-clean.tmp")
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

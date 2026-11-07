#!/usr/bin/env bash
# Renderiza los SVG a PNG con Chrome sin interfaz (vista previa, no se publica).
# Uso: ./render.sh [escala] [ancho] [alto]          -> mapa principal (claro y oscuro)
#      MODULO=N ./render.sh [escala] [ancho] [alto] -> variante "estás aquí" del módulo N
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p previews
for t in claro oscuro; do
  if [ -n "${MODULO:-}" ]; then
    src="../modulos/mapa-modulo-$MODULO-$t.svg"; out="previews/modulo-$MODULO-$t.png"
  else
    src="../mapa-del-curso-$t.svg"; out="previews/$t.png"
  fi
  google-chrome --headless=new --disable-gpu --hide-scrollbars --window-size=${2:-1000},${3:-800} \
    --force-device-scale-factor=${1:-1} --screenshot="$PWD/$out" "file://$PWD/$src" 2>/dev/null
done
ls -la previews

#!/usr/bin/env bash
# Renderiza los dos SVG a PNG con Chrome sin interfaz (vista previa, no se publica).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p previews
for t in claro oscuro; do
  google-chrome --headless=new --disable-gpu --hide-scrollbars --window-size=${2:-1000},${3:-800} \
    --force-device-scale-factor=${1:-1} --screenshot="$PWD/previews/$t.png" "file://$PWD/../mapa-del-curso-$t.svg" 2>/dev/null
done
ls -la previews

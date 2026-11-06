#!/bin/bash
# Prepara el Reto del Laboratorio 2 (Módulo 8): un compañero amplía el rango de la política a toda la línea 1.x
# y publica una v1.2.0 SIN firmar. Flux la desplegará sola, porque la automatización no verifica firmas.
set -euo pipefail
export GITEA_PASS="${GITEA_PASS:?haga export GITEA_PASS antes}"
. "$HOME/lab-gitops-2/env.sh"
g pull -q --rebase origin main
sed -i -E 's/^( *range:).*/\1 1.x/' "$W/fleet/apps/ruleta/imagepolicy.yaml"
g add -A
g -c user.name="Companero" -c user.email="companero@example.com" commit -qm "feat(policy): permitir toda la linea 1.x" || true
g push -q origin main
cd "$W/app"
docker build -q --provenance=false --build-arg VERSION=1.2.0 -t localhost:5092/ruleta:1.2.0 . >/dev/null
docker push -q localhost:5092/ruleta:1.2.0 >/dev/null
echo "Reto preparado: ruleta:1.2.0 está en el registro SIN firma y la política vuelve a permitir 1.x."

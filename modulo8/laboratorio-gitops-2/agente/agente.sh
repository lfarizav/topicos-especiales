#!/bin/bash
# AGENTE DE EJEMPLO, DETERMINISTA Y SIN MODELO DE LENGUAJE.
# Papel: proponer con evidencia. Nunca aplica nada al clúster y nunca fusiona.
# Un agente real con LLM (kagent, HolmesGPT, k8sgpt analyze --explain, un asistente de código) se conecta
# EXACTAMENTE en los pasos 2 y 4 (explicar la causa y redactar el cambio); el flujo no cambia:
# lee con RBAC de solo lectura, abre una rama, abre un PR con evidencia y espera a un humano.
set -euo pipefail
W="$HOME/lab-gitops-2"; export PATH="$W/bin:$PATH"
GIP=$(cat "$W/gitea.ip"); API="http://127.0.0.1:3092/api/v1"; REPO="http://$GIP:3000/lab/fleet.git"
TOK=$(cat "$W/llaves/agente.token")
export KUBECONFIG="$W/agente.kubeconfig"
test -s "$KUBECONFIG" || { echo "FALTA el kubeconfig del agente: corra agente-kubeconfig.sh (lo hace el humano)"; exit 1; }
NS=tienda; RAMA="agente/arreglo-catalogo"

echo "== 1. Triage determinista: k8sgpt analyze SIN --explain (ningun modelo, ninguna llamada externa)"
k8sgpt analyze --filter=Pod --namespace="$NS" --output=json --no-cache > "$W/triage.json"
cat "$W/triage.json"
IMG_MALA=$(python3 - "$W/triage.json" <<'PY'
import json,re,sys
d=json.load(open(sys.argv[1]))
for r in d.get("results") or []:
    for e in r.get("error") or []:
        m=re.search(r'image "([^"]+)"', e.get("Text",""))
        if m: print(m.group(1)); sys.exit(0)
sys.exit(1)
PY
) || { echo "El triage no encontro una imagen que no se puede bajar; no hay nada que proponer."; exit 2; }
echo "Hallazgo: la imagen $IMG_MALA no se puede bajar"

echo "== 2. Causa: la etiqueta no existe en el registro (aqui entraria el LLM a explicar)"
REPO_IMG=${IMG_MALA%:*}; NOMBRE=${REPO_IMG#*/}
TAGS=$(curl -fs "http://127.0.0.1:5092/v2/$NOMBRE/tags/list")
echo "$TAGS"
BUENA=$(echo "$TAGS" | python3 -c 'import json,sys;t=json.load(sys.stdin)["tags"];t.sort(key=lambda x:[int(p) for p in x.split(".")]);print(t[-1])')
DIG=$(curl -fsI -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json' "http://127.0.0.1:5092/v2/$NOMBRE/manifests/$BUENA" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}')

echo "== 3. Rama y cambio minimo en Git (el agente nunca toca el clúster)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
GG() { git -C "$T/r" -c credential.helper= -c http.extraHeader="Authorization: token $TOK" "$@"; }
git -c credential.helper= -c http.extraHeader="Authorization: token $TOK" clone -q "$REPO" "$T/r"
GG config user.name "agente"; GG config user.email "agente@example.com"
GG checkout -q -b "$RAMA"
sed -i "s#image: $IMG_MALA#image: $REPO_IMG:$BUENA#" "$T/r/apps/tienda/deployment.yaml"
GG diff --stat
GG commit -qam "fix(tienda): catalogo usa $REPO_IMG:$BUENA (la etiqueta ${IMG_MALA##*:} no existe)"
GG push -q origin "$RAMA"

echo "== 4. PR con evidencia (el agente redacta; el humano decide)"
CUERPO=$(python3 - "$W/triage.json" "$IMG_MALA" "$REPO_IMG" "$BUENA" "$DIG" <<'PY'
import json,sys
tri=json.load(open(sys.argv[1])); mala,repo,buena,dig=sys.argv[2:6]
print(f"""## Que encontre
`k8sgpt analyze --filter=Pod --namespace=tienda` (sin --explain, determinista) reporta un Pod que no puede bajar la imagen `{mala}`.

## Evidencia
```json
{json.dumps(tri, indent=1, ensure_ascii=False)[:1500]}
```
- Etiquetas que SI existen en el registro para `{repo}`: `{buena}` (digest `{dig}`).
- La etiqueta `{mala.rsplit(':',1)[1]}` no existe.

## Cambio propuesto
Una sola linea en `apps/tienda/deployment.yaml`: `{mala}` -> `{repo}:{buena}`.

## Limites
No aplique nada al cluster (mi ServiceAccount es de solo lectura). No puedo aprobar ni fusionar este PR: necesito una persona. Flux reconciliara despues de la fusion.""")
PY
)
PR=$(python3 - "$RAMA" "$CUERPO" <<'PY' | curl -fs -X POST "$API/repos/lab/fleet/pulls" -H "Authorization: token $TOK" -H 'Content-Type: application/json' -d @-
import json,sys
print(json.dumps({"title":"fix(tienda): catalogo apunta a una etiqueta que existe","head":sys.argv[1],"base":"main","body":sys.argv[2]}))
PY
)
NUM=$(echo "$PR" | python3 -c 'import json,sys;print(json.load(sys.stdin)["number"])')
echo "PR abierto: http://127.0.0.1:3092/lab/fleet/pulls/$NUM"

echo "== 5. Prueba de limites: el agente intenta fusionar su propio PR"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/repos/lab/fleet/pulls/$NUM/merge" -H "Authorization: token $TOK" -H 'Content-Type: application/json' -d '{"Do":"merge"}')
echo "respuesta al intento de autofusion: HTTP $CODE (se espera 403 o 405; cualquier 2xx seria un fallo de la proteccion)"
case "$CODE" in 2*) echo "ALERTA: el agente pudo fusionar"; exit 3;; esac
echo "Ahora le toca al humano: revisar el diff, aprobar y fusionar."

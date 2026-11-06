# Funciones comunes de los calificadores del Laboratorio 2 (Módulo 8). Se cargan con: . "$(dirname "$0")/_comun.sh"
W="$HOME/lab-gitops-2"; export PATH="$W/bin:$PATH" KUBECONFIG="$W/kubeconfig"
GIP=$(cat "$W/gitea.ip" 2>/dev/null) || { echo "FALLA: no existe $W/gitea.ip; corra el montaje"; exit 1; }
URL="http://$GIP:3000/lab/fleet.git"; API="http://127.0.0.1:3092/api/v1"; REG=127.0.0.1:5092
K() { kubectl "$@" 2>/dev/null; }
falla() { echo "FALLA: $*"; exit 1; }
# digest de una etiqueta del registro local (cabecera Docker-Content-Digest)
digest() { curl -fsI -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json' \
  "http://$REG/v2/$1/manifests/$2" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'; }
cosign_ok() { cosign verify --key "$W/llaves/cosign.pub" --insecure-ignore-tlog --allow-insecure-registry "$REG/$1@$2" >/dev/null 2>&1; }
# copia fresca y anonima del repositorio de flota
clonar() { CL=$(mktemp -d); git clone -q "$URL" "$CL/f" 2>/dev/null || falla "no pude clonar $URL"; }
# pods de la ruleta que NO estan terminando: "imagen imageID" por linea
pods_ruleta() { kubectl -n ruleta get pods -l app=ruleta -o json 2>/dev/null | python3 -c 'import json,sys
for p in json.load(sys.stdin)["items"]:
    if p["metadata"].get("deletionTimestamp"): continue
    cs=(p["status"].get("containerStatuses") or [{}])[0]
    print(p["spec"]["containers"][0]["image"], cs.get("imageID",""))'; }

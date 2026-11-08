#!/bin/bash
# Paso 9 del laboratorio 1 (módulo 8): inyecta un incidente de producción en TU laboratorio ya terminado.
# Uso: export GITEA_PASS=<la contraseña de montar.sh>; bash preparar-incidente.sh
# Se ejecuta UNA sola vez por montaje. Cada ejecución genera su propio token y su propio incidente:
# la evidencia de un compañero no sirve para ti. Tu tarea es dejar el sistema en el estado final del ticket.
set -euo pipefail
W="$HOME/lab-gitops-1"
export PATH="$W/bin:$PATH" KUBECONFIG="$W/kubeconfig" TF_VAR_kubeconfig="$W/kubeconfig"
API="http://127.0.0.1:3088/api/v1"
fallo() { echo "ERROR: $*" >&2; exit 1; }
gq() { grep "$@" >/dev/null; }   # grep -q que lee toda la entrada (seguro con pipefail)
K() { kubectl "$@" 2>/dev/null; }

GITEA_PASS="${GITEA_PASS:-}"
test "${#GITEA_PASS}" -ge 12 2>/dev/null || fallo "haga export GITEA_PASS=<la contrasena que uso en montar.sh> y repita"
for t in kubectl flux git curl python3; do command -v $t >/dev/null || fallo "falta $t en el PATH"; done
test -s "$W/gitea.ip" -a -e "$W/.montaje-completo" || fallo "no hay un laboratorio montado en $W; corra primero bash montar.sh y termine los pasos anteriores"
kubectl get nodes >/dev/null 2>&1 || fallo "kubectl no alcanza el cluster del laboratorio"
curl -fs -u "lab:$GITEA_PASS" "$API/user" >/dev/null || fallo "Gitea no acepta GITEA_PASS (o no responde en 127.0.0.1:3088)"

# Un solo incidente por montaje (el registro vive en el estado local Y en el servidor Git, para que no se pueda reiniciar)
DESC=$(curl -fs -u "lab:$GITEA_PASS" "$API/repos/lab/fleet" | python3 -I -c 'import sys,json; print(json.load(sys.stdin).get("description",""))')
if test -e "$W/.incidente" || echo "$DESC" | gq '^incidente-'; then
  fallo "este montaje ya recibio su incidente y no se reinicia. Resuelvalo; para uno nuevo hay que desmontar y rehacer el laboratorio."
fi

# El incidente se inyecta sobre un laboratorio TERMINADO: se mide que lo este.
# (Con wait: true la Kustomization apps pasa un rato en Ready=Unknown tras cada cambio: se le da hasta 2 minutos.)
for i in $(seq 1 40); do test "$(K -n flux-system get kustomization apps -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True && break; sleep 3; done
FALTA=""
for d in source-controller kustomize-controller; do
  K -n flux-system get deploy $d -o jsonpath='{.status.availableReplicas}' | gq -x 1 || FALTA="$FALTA [Flux: $d no disponible]"
done
test "$(K -n flux-system get kustomization apps -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True || FALTA="$FALTA [la Kustomization apps no existe o no esta Ready]"
test "$(K -n flux-system get kustomization apps -o jsonpath='{.spec.suspend}')" != true || FALTA="$FALTA [apps ya esta suspendida]"
test "$(K -n saludo get deploy saludo -o jsonpath='{.status.availableReplicas}')" = "$(K -n saludo get deploy saludo -o jsonpath='{.spec.replicas}')" || FALTA="$FALTA [saludo no esta sano]"
test "$(K -n iac-lab get cm ajustes -o jsonpath='{.data.nivel}')" = produccion || FALTA="$FALTA [OpenTofu: iac-lab/ajustes no dice produccion]"
test -x "$W/fleet/.git/hooks/pre-commit" || FALTA="$FALTA [falta el gancho pre-commit]"
test -z "$FALTA" || fallo "tu laboratorio aun no esta terminado (resuelva el Paso 8 primero): $FALTA"

TK="INC-$(python3 -I -c 'import secrets; print(secrets.token_hex(4))')"
UID_C=$(K get ns kube-system -o jsonpath='{.metadata.uid}'); test -n "$UID_C" || fallo "no se pudo leer el identificador del cluster"
MARCA="incidente-$(printf 'marca|%s|%s' "$TK" "$UID_C" | sha256sum | cut -c1-16)"
FECHA=$(date +%Y-%m-%dT%H:%M:%S%z)
trap 'rc=$?; if test $rc -ne 0; then echo "LA INYECCION SE DETUVO (codigo $rc). Desmonte con desmontar.sh y vuelva a montar para empezar de nuevo." >&2; fi' EXIT

# Causa 1: un "compañero" empuja por la API de Gitea (no pasa por tu gancho local) un cambio que rompe saludo
SAL=$(TK="$TK" API="$API" python3 -I - <<'PY'
import os, json, base64, re, secrets, urllib.request
api = os.environ["API"]; tk = os.environ["TK"]
tok = base64.b64encode(("lab:" + os.environ["GITEA_PASS"]).encode()).decode()
def call(metodo, ruta, datos=None):
    req = urllib.request.Request(api + ruta, method=metodo, data=None if datos is None else json.dumps(datos).encode(),
        headers={"Authorization": "Basic " + tok, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=30))
ruta = "/repos/lab/fleet/contents/apps/saludo/deployment.yaml"
j = call("GET", ruta + "?ref=main")
txt = base64.b64decode(j["content"]).decode()
m = re.search(r'^(\s*image:\s*)(\S+)[ \t]*$', txt, re.M)
assert m, "no hay linea image: en deployment.yaml"
img = m.group(2); base = img.split("@")[0]; ultimo = base.rsplit("/", 1)[-1]
h = secrets.token_hex(3)
malo = base + ("-rc" if ":" in ultimo else ":rc") + h
nuevo = txt[:m.start(2)] + malo + txt[m.end(2):]
quien = {"name": "Carlos Perez", "email": "carlos@example.com"}
r = call("PUT", ruta, {"content": base64.b64encode(nuevo.encode()).decode(), "sha": j["sha"], "branch": "main",
    "message": "feat(saludo): imagen de la campana [%s]" % tk, "author": quien, "committer": quien})
print(r["commit"]["sha"]); print(img)
PY
) || fallo "no se pudo crear el commit del companero en Gitea"
BADSHA=$(echo "$SAL" | sed -n 1p); PREIMG=$(echo "$SAL" | sed -n 2p)
echo "$BADSHA" | gq -x '[0-9a-f]\{40\}' || fallo "Gitea no devolvio el SHA del commit"

# Estado esperado: fuera del repositorio, solo legible por ti
umask 077
{ echo "TK='$TK'"; echo "BADSHA='$BADSHA'"; echo "PREIMG='$PREIMG'"; echo "CLUSTER_UID='$UID_C'"; echo "MARCA='$MARCA'"; echo "FECHA='$FECHA'"; } > "$W/.incidente"
curl -fs -u "lab:$GITEA_PASS" -X PATCH "$API/repos/lab/fleet" -H 'Content-Type: application/json' -d "{\"description\":\"$MARCA\"}" >/dev/null || fallo "no se pudo registrar el incidente en Gitea"

# Flux alcanza el commit malo; esperamos a que el sintoma sea visible antes de la causa 2
flux reconcile source git flux-system -n flux-system --timeout=30s >/dev/null 2>&1 || true
for i in $(seq 1 40); do
  K -n saludo get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' | gq -E 'ImagePull|ErrImage' && break
  sleep 3
done

# Causa 2: alguien "detuvo el daño" pausando la entrega y nadie la reanudo
flux suspend kustomization apps -n flux-system >/dev/null 2>&1 || fallo "no se pudo pausar la entrega"

# Causa 3: alguien tocó a mano un valor que el código de OpenTofu declara
kubectl --field-manager=companero -n iac-lab patch cm ajustes --type merge -p "{\"data\":{\"nivel\":\"prueba-$(python3 -I -c 'import secrets; print(secrets.token_hex(3))')\"}}" >/dev/null \
  || fallo "no se pudo introducir la deriva de OpenTofu"

cat <<TICKET

================ TICKET DE INCIDENTE $TK ================
Prioridad: alta. Reportado por la guardia de produccion el $FECHA.

Sintomas:
  - Desde hace unos minutos, los Pods nuevos de la aplicacion saludo no arrancan.
    Carlos Perez dice que subio "una mejora de la campana" y que, como tenia prisa,
    no la paso por la compuerta.
  - Alguien intento "detener el dano" y dejo algo a medias; el equipo no recuerda que.
  - OpenTofu ya no reconoce el ConfigMap ajustes del namespace iac-lab como suyo.

Estado final exigido (todo debe entrar por Git o por OpenTofu, nada a mano):
  1. El cambio de Carlos queda deshecho SIN borrarlo de la historia de main
     (auditoria exige ver el cambio y su reversa).
  2. saludo vuelve a su imagen anterior al incidente, con todas sus replicas disponibles,
     y la Kustomization apps aplica el ultimo commit de main.
  3. Existe un ConfigMap llamado ticket en el namespace saludo con data.token = $TK,
     entregado por Git a traves de la Kustomization flux-system (la que lee clusters/m08).
  4. iac-lab/ajustes vuelve a producir nivel=produccion y 'tofu plan' queda vacio.
  5. Nadie escribio estos objetos con kubectl (managedFields), y los siete chequeos
     anteriores del verificador siguen en [OK].

Cuando creas que terminaste:  bash verificador-reto1.sh
Copia el token ahora: este ticket no se vuelve a imprimir.
========================================================
TICKET

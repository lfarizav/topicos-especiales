#!/bin/bash
# Montaje del laboratorio 1 del módulo 8 (GitOps desde cero). Un cluster kind propio, un Gitea y un registro locales.
# Se puede repetir: si un montaje anterior se detuvo, lo limpia y empieza de nuevo. Requiere: export GITEA_PASS=<contrasena de 12+ caracteres inventada por usted> (nunca se escribe en archivos del repo)
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$HOME/lab-gitops-1"
CL=m08-gitops1; GT=gitops1-gitea; RG=gitops1-registry
NODO_IMG="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
GITEA_IMG="gitea/gitea:1.27.2-rootless@sha256:c7953964c6e8fe532cf7fc3f3efdea1d0b161d7859c47e04f5e05489d494dea0"
REG_IMG="registry:3@sha256:1be55279f18a2fe1a74edf2664cac61c1bea305b7b4642dab412e7affdcb3e33"
BB="busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0"
AL="alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce"
FLUX_V=2.10.0; KC_V=0.8.0; TOFU_V=1.12.6; COSIGN_V=3.1.3
SIGUIENTE="QUE HACER AHORA: 1) lea el ERROR de arriba y corrija esa causa; 2) bash $LAB_DIR/desmontar.sh; 3) export GITEA_PASS=<su contrasena>; 4) bash $LAB_DIR/montar.sh. (montar.sh se puede repetir las veces que haga falta.)"
fallo() { echo "ERROR $1: $2" >&2; exit 1; }
# Si el montaje se detiene por cualquier causa (con fallo() o por un comando que falla), dice exactamente que hacer
alsalir() { local rc=$?; if test $rc -ne 0; then echo "" >&2; echo "EL MONTAJE SE DETUVO (codigo $rc)." >&2; echo "$SIGUIENTE" >&2; fi; }
trap alsalir EXIT

# 1. Comprobaciones previas (se mide, no se asume). Aun no se crea nada.
GITEA_PASS="${GITEA_PASS:-}"
test "${#GITEA_PASS}" -ge 12 2>/dev/null || fallo CONTRASENA "haga export GITEA_PASS=<12 o mas caracteres> y repita bash montar.sh"
for t in docker kind kubectl git curl tar unzip sha256sum python3; do command -v $t >/dev/null || fallo HERRAMIENTA-FALTANTE "$t no esta en el PATH; instalela y repita bash montar.sh"; done
docker info >/dev/null 2>&1 || fallo DOCKER "docker no responde sin sudo; arregle Docker y repita bash montar.sh"

# 1b. Idempotencia: si hay restos de un montaje anterior que NO termino, se limpian solos; si termino, no se rehace.
hay_restos() { test -e "$W" || kind get clusters 2>/dev/null | grep -x $CL >/dev/null || docker ps -a --format '{{.Names}}' | grep -Ex "$GT|$RG" >/dev/null; }
if test -e "$W/.montaje-completo" && kind get clusters 2>/dev/null | grep -x $CL >/dev/null; then
  echo "El laboratorio ya esta montado ($W). Nada que hacer."
  echo "Para empezar de cero: bash $LAB_DIR/desmontar.sh && bash $LAB_DIR/montar.sh"
  echo "Para trabajar en una terminal nueva: source $W/entorno.sh"
  exit 0
fi
if hay_restos; then
  echo "Hay restos de un montaje anterior que no termino: se limpian con desmontar.sh antes de continuar."
  bash "$LAB_DIR/desmontar.sh"
fi

# 1c. El entorno se escribe PRIMERO, para que 'source ~/lab-gitops-1/entorno.sh' funcione aunque un paso posterior falle
mkdir -p "$W/bin" "$W/llaves" "$W/tofu"
cat > "$W/entorno.sh" <<EEOF
# Entorno de cada terminal del laboratorio 1 (modulo 8). Se escribe al inicio de montar.sh.
W="\$HOME/lab-gitops-1"
LAB_DIR="$LAB_DIR"
export PATH="\$W/bin:\$PATH" KUBECONFIG="\$W/kubeconfig" TF_VAR_kubeconfig="\$W/kubeconfig"
if test "\${#GITEA_PASS}" -lt 12; then
  echo "AVISO: falta GITEA_PASS en esta terminal. Haga export GITEA_PASS=<la contrasena que uso en montar.sh>." >&2
  echo "Si la olvido: docker exec gitops1-gitea gitea admin user change-password --username lab --password <NUEVA-de-12-o-mas> --must-change-password=false ; y luego export GITEA_PASS=<NUEVA>" >&2
fi
EEOF

# 1d. Puertos libres (se mide despues de escribir el entorno, para que entorno.sh exista aunque esto falle)
for p in 3088 5088; do if ss -ltn 2>/dev/null | grep "127.0.0.1:$p " >/dev/null; then fallo PUERTO-OCUPADO "el puerto $p de 127.0.0.1 lo usa otro programa; liberelo y repita bash montar.sh (no lo cierra este laboratorio)"; fi; done

# 2. Herramientas fijadas por version, con la suma SHA-256 del lanzamiento oficial (verificadas el 2026-11-06)
bajar() { # url destino suma
  curl -fsSL "$1" -o "$2" || fallo DESCARGA "$1"
  echo "$3  $2" | sha256sum -c - >/dev/null || fallo SUMA-SHA256 "no coincide la suma de $1"; }
T=$(mktemp -d)
bajar https://github.com/fluxcd/flux2/releases/download/v$FLUX_V/flux_${FLUX_V}_linux_amd64.tar.gz $T/flux.tgz 208dd7012c04fedeed5b2d0b6e63df3b15b1c34a381527811685c098bc9f8659
tar -xzf $T/flux.tgz -C "$W/bin" flux
bajar https://github.com/yannh/kubeconform/releases/download/v$KC_V/kubeconform-linux-amd64.tar.gz $T/kc.tgz 9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
tar -xzf $T/kc.tgz -C "$W/bin" kubeconform
bajar https://github.com/opentofu/opentofu/releases/download/v$TOFU_V/tofu_${TOFU_V}_linux_amd64.zip $T/tofu.zip 5dc43da4f750f33873dc25e94587128709e819e544b7be9016b255316153c3a8
unzip -oq $T/tofu.zip tofu -d "$W/bin"
bajar https://github.com/sigstore/cosign/releases/download/v$COSIGN_V/cosign-linux-amd64 "$W/bin/cosign" 4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71
chmod +x "$W/bin/"*; rm -rf $T
export PATH="$W/bin:$PATH"
flux --version; kubeconform -v; tofu version | head -1; cosign version 2>&1 | grep GitVersion

# 3. Cluster kind propio, con kubeconfig privado
kind create cluster --name $CL --image "$NODO_IMG" --kubeconfig "$W/kubeconfig" --wait 120s
export KUBECONFIG="$W/kubeconfig"
kubectl get nodes --no-headers | grep -w Ready >/dev/null || fallo NODO "el nodo no esta Ready"

# 4. Gitea local (el servidor Git del laboratorio) en la red de kind
docker run -d --name $GT --network kind -p 127.0.0.1:3088:3000 \
  -e GITEA__security__INSTALL_LOCK=true -e GITEA__service__DISABLE_REGISTRATION=true "$GITEA_IMG" >/dev/null
for i in $(seq 1 60); do curl -fs http://127.0.0.1:3088/api/healthz >/dev/null 2>&1 && break; sleep 2; done
curl -fs http://127.0.0.1:3088/api/healthz >/dev/null || fallo GITEA "Gitea no respondio en 120 s"
docker exec $GT gitea admin user create --admin --username lab --password "$GITEA_PASS" --email lab@example.com --must-change-password=false >/dev/null
curl -fs -u "lab:$GITEA_PASS" -X POST http://127.0.0.1:3088/api/v1/user/repos -H 'Content-Type: application/json' \
  -d '{"name":"fleet","private":false,"auto_init":true,"default_branch":"main"}' >/dev/null || fallo REPO "no se pudo crear lab/fleet"
GIP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' $GT)
test -n "$GIP" || fallo GITEA-IP "Gitea no tiene IP en la red kind"
docker exec $CL-control-plane curl -fs "http://$GIP:3000/api/healthz" >/dev/null || fallo SUSTRATO-SIN-RUTA-A-GITEA "el nodo kind no alcanza Gitea en $GIP:3000; Flux no podria leer el repositorio"
echo "$GIP" > "$W/gitea.ip"

# 5. Registro local con dos imagenes: una para firmar y una "intrusa" que nunca se firma
docker run -d --name $RG -p 127.0.0.1:5088:5000 "$REG_IMG" >/dev/null
for i in $(seq 1 30); do curl -fs http://127.0.0.1:5088/v2/ >/dev/null 2>&1 && break; sleep 1; done
curl -fs http://127.0.0.1:5088/v2/ >/dev/null || fallo REGISTRO "el registro no respondio"
docker pull -q "$BB" >/dev/null; docker pull -q "$AL" >/dev/null
docker tag "$BB" localhost:5088/lab/hola:1.0.0; docker tag "$AL" localhost:5088/lab/intruso:1.0.0
docker push -q localhost:5088/lab/hola:1.0.0 >/dev/null; docker push -q localhost:5088/lab/intruso:1.0.0 >/dev/null

# 6. Envoltorio de git: la contrasena sale de la variable GITEA_PASS, nunca de un archivo
cat > "$W/bin/g" <<'GEOF'
#!/bin/bash
: "${GITEA_PASS:?haga export GITEA_PASS antes}"
W="$HOME/lab-gitops-1"
# credential.helper= (vacio) descarta los helpers globales (store, libsecret...): si no, git guardaria la contrasena en ~/.git-credentials
exec git -C "$W/fleet" -c credential.helper= -c credential.helper='!f() { echo username=lab; echo "password=$GITEA_PASS"; }; f' "$@"
GEOF
chmod +x "$W/bin/g"
git clone -q "http://$GIP:3000/lab/fleet.git" "$W/fleet"
git -C "$W/fleet" config user.name "Alumno del laboratorio"; git -C "$W/fleet" config user.email "alumno@example.com"
touch "$W/.montaje-completo"
echo "MONTAJE LISTO. Gitea: http://$GIP:3000/lab/fleet.git  Registro: localhost:5088  Carpeta: $W"
echo "SIGUIENTE PASO: source $W/entorno.sh   (en cada terminal nueva; la contrasena GITEA_PASS tambien hay que exportarla en cada una)"

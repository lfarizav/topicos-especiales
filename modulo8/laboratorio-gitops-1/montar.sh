#!/bin/bash
# Montaje del laboratorio 1 del módulo 8 (GitOps desde cero). Un cluster kind propio, un Gitea y un registro locales.
# Requiere: export GITEA_PASS=<contrasena de 12+ caracteres inventada por usted> (nunca se escribe en archivos del repo)
set -euo pipefail
W="$HOME/lab-gitops-1"
CL=m08-gitops1; GT=gitops1-gitea; RG=gitops1-registry
NODO_IMG="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
GITEA_IMG="gitea/gitea:1.27.2-rootless@sha256:c7953964c6e8fe532cf7fc3f3efdea1d0b161d7859c47e04f5e05489d494dea0"
REG_IMG="registry:3@sha256:1be55279f18a2fe1a74edf2664cac61c1bea305b7b4642dab412e7affdcb3e33"
BB="busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0"
AL="alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce"
FLUX_V=2.10.0; KC_V=0.8.0; TOFU_V=1.12.6; COSIGN_V=3.1.3
fallo() { echo "ERROR $1: $2" >&2; exit 1; }

# 1. Comprobaciones previas (se mide, no se asume)
test "${#GITEA_PASS}" -ge 12 2>/dev/null || fallo CONTRASENA "haga export GITEA_PASS=<12 o mas caracteres> antes del montaje"
for t in docker kind kubectl git curl tar unzip sha256sum python3; do command -v $t >/dev/null || fallo HERRAMIENTA-FALTANTE "$t no esta en el PATH"; done
docker info >/dev/null 2>&1 || fallo DOCKER "docker no responde sin sudo"
for p in 3088 5088; do if ss -ltn 2>/dev/null | grep -q "127.0.0.1:$p "; then fallo PUERTO-OCUPADO "el puerto $p de 127.0.0.1 debe estar libre"; fi; done
if kind get clusters 2>/dev/null | grep -qx $CL; then fallo CLUSTER-EXISTE "corra primero el teardown"; fi
if test -e "$W"; then fallo CARPETA-EXISTE "$W existe; corra primero el teardown"; fi
mkdir -p "$W/bin" "$W/llaves" "$W/tofu"

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
kubectl get nodes --no-headers | grep -qw Ready || fallo NODO "el nodo no esta Ready"

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
# 7. Entorno de cada terminal: W, PATH con las herramientas fijadas y el kubeconfig privado del laboratorio
cat > "$W/entorno.sh" <<EEOF
W="\$HOME/lab-gitops-1"
LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="\$W/bin:\$PATH" KUBECONFIG="\$W/kubeconfig" TF_VAR_kubeconfig="\$W/kubeconfig"
EEOF
echo "MONTAJE LISTO. Gitea: http://$GIP:3000/lab/fleet.git  Registro: localhost:5088  Carpeta: $W"

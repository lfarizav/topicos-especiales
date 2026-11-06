#!/bin/bash
# Montaje del Laboratorio 2 (Módulo 8): el ciclo de vida de la ruleta y el agente que propone.
# Un cluster kind propio (gitops2), un Gitea y un registro locales. No toca ningun otro cluster.
# Requiere: export GITEA_PASS=<contrasena de 12+ caracteres inventada por usted> (nunca se escribe en archivos del repo)
# Se corre DESDE la carpeta que contiene este archivo.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
W="$HOME/lab-gitops-2"
CL=gitops2; GT=gitops2-gitea; RG=gitops2-registry; PG=3092; PR=5092
NODO_IMG="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
GITEA_IMG="gitea/gitea:1.27.2-rootless@sha256:c7953964c6e8fe532cf7fc3f3efdea1d0b161d7859c47e04f5e05489d494dea0"
REG_IMG="registry:3@sha256:1be55279f18a2fe1a74edf2664cac61c1bea305b7b4642dab412e7affdcb3e33"
BB="busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0"
AL="alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce"
FLUX_V=2.10.0; COSIGN_V=3.1.3; K8SGPT_V=0.4.41
fallo() { echo "ERROR $1: $2" >&2; exit 1; }

# 1. Comprobaciones previas (se mide, no se asume)
test "${#GITEA_PASS}" -ge 12 2>/dev/null || fallo CONTRASENA "haga export GITEA_PASS=<12 o mas caracteres> antes del montaje"
for t in docker kind kubectl git curl tar sha256sum python3 base64; do command -v $t >/dev/null || fallo HERRAMIENTA-FALTANTE "$t no esta en el PATH"; done
docker info >/dev/null 2>&1 || fallo DOCKER "docker no responde sin sudo"
for p in $PG $PR; do if ss -ltn 2>/dev/null | grep -q "127.0.0.1:$p "; then fallo PUERTO-OCUPADO "el puerto $p de 127.0.0.1 debe estar libre"; fi; done
if kind get clusters 2>/dev/null | grep -qx $CL; then fallo CLUSTER-EXISTE "corra primero el teardown"; fi
if test -e "$W"; then fallo CARPETA-EXISTE "$W existe; corra primero el teardown"; fi
test -f "$AQUI/ruleta/app.py" || fallo MATERIAL "no encuentro ../ruleta junto a este montaje"
mkdir -p "$W/bin" "$W/llaves"

# 2. Herramientas fijadas por version, con la suma SHA-256 del lanzamiento oficial (verificadas el 2026-11-06)
bajar() { # url destino suma
  curl -fsSL "$1" -o "$2" || fallo DESCARGA "$1"
  echo "$3  $2" | sha256sum -c - >/dev/null || fallo SUMA-SHA256 "no coincide la suma de $1"; }
T=$(mktemp -d)
bajar https://github.com/fluxcd/flux2/releases/download/v$FLUX_V/flux_${FLUX_V}_linux_amd64.tar.gz $T/flux.tgz 208dd7012c04fedeed5b2d0b6e63df3b15b1c34a381527811685c098bc9f8659
tar -xzf $T/flux.tgz -C "$W/bin" flux
bajar https://github.com/sigstore/cosign/releases/download/v$COSIGN_V/cosign-linux-amd64 "$W/bin/cosign" 4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71
bajar https://github.com/k8sgpt-ai/k8sgpt/releases/download/v$K8SGPT_V/k8sgpt_Linux_x86_64.tar.gz $T/k8sgpt.tgz e56b5cbe826dbf1e314075453105426acca2ad4410e64073d665c697c97208ed
tar -xzf $T/k8sgpt.tgz -C "$W/bin" k8sgpt
chmod +x "$W/bin/"*; rm -rf $T
export PATH="$W/bin:$PATH"
flux --version; cosign version 2>&1 | grep GitVersion; k8sgpt version

# 3. Cluster kind propio, con kubeconfig privado y el registro local declarado a containerd
cat > "$W/kind.yaml" <<KEOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CL
nodes:
  - role: control-plane
    image: $NODO_IMG
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
KEOF
kind create cluster --config "$W/kind.yaml" --kubeconfig "$W/kubeconfig" --wait 120s
export KUBECONFIG="$W/kubeconfig"
kubectl get nodes --no-headers | grep -qw Ready || fallo NODO "el nodo no esta Ready"
docker exec $CL-control-plane mkdir -p /etc/containerd/certs.d/$RG:5000
printf 'server = "http://%s:5000"\n[host."http://%s:5000"]\n  capabilities = ["pull","resolve"]\n' $RG $RG \
  | docker exec -i $CL-control-plane tee /etc/containerd/certs.d/$RG:5000/hosts.toml >/dev/null

# 4. Gitea local (el servidor Git del laboratorio) en la red de kind
docker run -d --name $GT --network kind -p 127.0.0.1:$PG:3000 \
  -e GITEA__security__INSTALL_LOCK=true -e GITEA__service__DISABLE_REGISTRATION=true "$GITEA_IMG" >/dev/null
for i in $(seq 1 60); do curl -fs http://127.0.0.1:$PG/api/healthz >/dev/null 2>&1 && break; sleep 2; done
curl -fs http://127.0.0.1:$PG/api/healthz >/dev/null || fallo GITEA "Gitea no respondio en 120 s"
docker exec $GT gitea admin user create --admin --username lab --password "$GITEA_PASS" --email lab@example.com --must-change-password=false >/dev/null
AGP=$(python3 -c 'import secrets;print(secrets.token_urlsafe(18))')
docker exec $GT gitea admin user create --username agente --password "$AGP" --email agente@example.com --must-change-password=false >/dev/null
docker exec $GT gitea admin user generate-access-token --username agente --token-name agente --scopes write:repository,read:repository,write:issue,read:user --raw > "$W/llaves/agente.token"
chmod 600 "$W/llaves/agente.token"
test -s "$W/llaves/agente.token" || fallo TOKEN-AGENTE "no se pudo generar el token del usuario agente"
API="http://127.0.0.1:$PG/api/v1"
curl -fs -u "lab:$GITEA_PASS" -X POST $API/user/repos -H 'Content-Type: application/json' \
  -d '{"name":"fleet","private":false,"auto_init":true,"default_branch":"main"}' >/dev/null || fallo REPO "no se pudo crear lab/fleet"
curl -fs -u "lab:$GITEA_PASS" -X PUT $API/repos/lab/fleet/collaborators/agente -H 'Content-Type: application/json' \
  -d '{"permission":"write"}' >/dev/null || fallo COLABORADOR "no se pudo dar escritura al agente"
# main protegida: solo el humano (lab) empuja y fusiona; las fusiones exigen una aprobacion de otra persona
curl -fs -u "lab:$GITEA_PASS" -X POST $API/repos/lab/fleet/branch_protections -H 'Content-Type: application/json' \
  -d '{"branch_name":"main","enable_push":true,"enable_push_whitelist":true,"push_whitelist_usernames":["lab"],"enable_merge_whitelist":true,"merge_whitelist_usernames":["lab"],"required_approvals":1}' >/dev/null \
  || fallo PROTECCION "no se pudo proteger main"
GIP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' $GT)
test -n "$GIP" || fallo GITEA-IP "Gitea no tiene IP en la red kind"
docker exec $CL-control-plane curl -fs "http://$GIP:3000/api/healthz" >/dev/null || fallo SUSTRATO-SIN-RUTA-A-GITEA "el nodo kind no alcanza Gitea en $GIP:3000; Flux no podria leer el repositorio"
echo "$GIP" > "$W/gitea.ip"

# 5. Registro local en la red de kind (los nodos lo llaman por nombre); imagenes de apoyo
docker run -d --name $RG --network kind -p 127.0.0.1:$PR:5000 "$REG_IMG" >/dev/null
for i in $(seq 1 30); do curl -fs http://127.0.0.1:$PR/v2/ >/dev/null 2>&1 && break; sleep 1; done
curl -fs http://127.0.0.1:$PR/v2/ >/dev/null || fallo REGISTRO "el registro no respondio"
docker exec $CL-control-plane curl -fs http://$RG:5000/v2/ >/dev/null || fallo SUSTRATO-SIN-RUTA-AL-REGISTRO "el nodo kind no alcanza $RG:5000; los pods no podrian bajar imagenes"
docker pull -q "$BB" >/dev/null; docker pull -q "$AL" >/dev/null
docker tag "$BB" localhost:$PR/catalogo:1.0.0; docker tag "$AL" localhost:$PR/intruso:1.0.0
docker push -q localhost:$PR/catalogo:1.0.0 >/dev/null; docker push -q localhost:$PR/intruso:1.0.0 >/dev/null

# 6. Copia de trabajo de la app, con un defecto que se aplica desde una carga opaca (cortesia, no ocultamiento real)
cp -r "$AQUI/ruleta" "$W/app"
find "$W/app" -name __pycache__ -prune -exec rm -rf {} +
echo 'aW1wb3J0IHBhdGhsaWIscmUKcD1wYXRobGliLlBhdGgoJ3J1bGV0YS5weScpCnM9cC5yZWFkX3RleHQoKQpzPXJlLnN1YignTUFYX1ZBTE9SRVMgPSAyLCAxMCcsJ01BWF9WQUxPUkVTID0gMiwgMTEnLCBzKQpwLndyaXRlX3RleHQocyk=' | base64 -d > "$W/.carga.py"
(cd "$W/app" && python3 "$W/.carga.py") ; rm -f "$W/.carga.py"
( cd "$W/app/tests" && sha256sum *.py | sha256sum | cut -d' ' -f1 ) > "$W/.tests.sha"
python3 -m venv "$W/venv" && "$W/venv/bin/pip" install -q -r "$W/app/requirements-dev.txt"

# 7. Material de la tarea (plantilla de flota, observabilidad, agente) y calificadores
cp -r "$AQUI/plantilla" "$AQUI/observabilidad" "$AQUI/agente" "$AQUI/comprobar" "$W/"
chmod +x "$W/agente/"*.sh "$W/comprobar/"*.sh

# 8. Envoltorio de git: la contrasena sale de la variable GITEA_PASS, nunca de un archivo
cat > "$W/bin/g" <<'GEOF'
#!/bin/bash
: "${GITEA_PASS:?haga export GITEA_PASS antes}"
W="$HOME/lab-gitops-2"
exec git -C "$W/fleet" -c credential.helper= -c credential.helper='!f() { echo username=lab; echo "password=$GITEA_PASS"; }; f' "$@"
GEOF
chmod +x "$W/bin/g"
git clone -q "http://$GIP:3000/lab/fleet.git" "$W/fleet" 2>/dev/null || \
  git -c credential.helper= -c credential.helper='!f() { echo username=lab; echo "password=$GITEA_PASS"; }; f' clone -q "http://$GIP:3000/lab/fleet.git" "$W/fleet"
git -C "$W/fleet" config user.name "Alumno del laboratorio"; git -C "$W/fleet" config user.email "alumno@example.com"
cat > "$W/env.sh" <<'EEOF'
# Cargue con:  . ~/lab-gitops-2/env.sh   (necesita GITEA_PASS exportada)
export W="$HOME/lab-gitops-2"
export PATH="$W/bin:$PATH" KUBECONFIG="$W/kubeconfig"
export API="http://127.0.0.1:3092/api/v1" GIP="$(cat "$W/gitea.ip")"
: "${GITEA_PASS:?haga export GITEA_PASS antes}"
EEOF
echo "export MAT=\"$AQUI\"" >> "$W/env.sh"
cat >> "$W/env.sh" <<'EEOF'
# digest de una etiqueta del registro local: digest_de ruleta 1.0.0  ->  sha256:...
digest_de() { curl -fsI -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
  "http://127.0.0.1:5092/v2/$1/manifests/$2" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'; }
EEOF
echo "MONTAJE LISTO. Gitea: http://$GIP:3000/lab/fleet.git  Registro: localhost:$PR  Carpeta: $W"

#!/usr/bin/env bash
# Verificador del Reto 1 (módulo 8, GitOps): califica el ESTADO FINAL, no los comandos que usaste.
# Uso: bash verificador-reto1.sh        (despues de bash montar.sh; no necesita estar en ninguna carpeta)
# Salida: una línea [OK]/[FALLA] por chequeo (con el motivo) y "Resultado: X/7".
# Código de salida: 0 si sacas 7/7, 1 si no.
# Atención: los chequeos 3, 4 y 7 PROVOCAN una falla a propósito (escalan un Deployment, editan un ConfigMap)
# y esperan a que tu sistema la corrija. Tarda entre 1 y 4 minutos.
set -uo pipefail

W="$HOME/lab-gitops-1"
export PATH="$W/bin:$PATH" KUBECONFIG="$W/kubeconfig" TF_VAR_kubeconfig="$W/kubeconfig"
for t in kubectl git curl docker; do command -v $t >/dev/null || { echo "ERROR: falta $t"; exit 2; }; done
test -d "$W" && test -s "$W/gitea.ip" || { echo "ERROR: no existe $W; corre primero bash montar.sh"; exit 2; }
kubectl get nodes >/dev/null 2>&1 || { echo "ERROR: kubectl no alcanza el clúster del laboratorio"; exit 2; }
GIP=$(cat "$W/gitea.ip"); URL="http://$GIP:3000/lab/fleet.git"
OK=0; TOTAL=0

chequeo() {  # $1 = descripción, resto = función que imprime el motivo y sale con 1 si el mundo está mal
  local desc=$1; shift; local motivo
  TOTAL=$((TOTAL+1))
  if motivo=$("$@" 2>&1); then echo "  [OK]    $desc"; OK=$((OK+1)); [ -n "$motivo" ] && echo "            -> $motivo"
  else echo "  [FALLA] $desc"; [ -n "$motivo" ] && echo "            -> $motivo"; fi
}
K() { kubectl "$@" 2>/dev/null; }

# ---------- 1. Flux se instaló a sí mismo desde Git ----------
c_flux() (
  for d in source-controller kustomize-controller helm-controller notification-controller; do
    kubectl -n flux-system get deploy $d -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qx 1 || { echo "$d no está disponible"; exit 1; }
  done
  K -n flux-system get gitrepository flux-system -o jsonpath='{.spec.url}' | grep -qx "$URL" || { echo "la fuente no apunta a $URL"; exit 1; }
  K -n flux-system get gitrepository flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -qx True || { echo "GitRepository no está Ready"; exit 1; }
  K -n flux-system get kustomization flux-system -o jsonpath='{.spec.path}' | grep -qx './clusters/m08' || { echo "el path debe ser ./clusters/m08"; exit 1; }
  test "$(K -n flux-system get kustomization flux-system -o jsonpath='{.spec.suspend}')" != true || { echo "Kustomization flux-system suspendida"; exit 1; }
  HEAD=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$URL" refs/heads/main | cut -f1); test -n "$HEAD" || { echo "Gitea no responde"; exit 1; }
  K -n flux-system get kustomization flux-system -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || { echo "Flux no aplicó el HEAD actual ($HEAD)"; exit 1; }
  curl -fs "http://$GIP:3000/lab/fleet/raw/branch/main/clusters/m08/flux-system/gotk-sync.yaml" | grep -q 'kind: GitRepository' || { echo "gotk-sync.yaml no está en Git"; exit 1; }
  K -n flux-system get secret flux-system >/dev/null || { echo "falta el Secret flux-system"; exit 1; }
)

# ---------- 2. La aplicación entró por Git, no por kubectl ----------
c_app() (
  test "$(K -n flux-system get kustomization apps -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True || { echo "la Kustomization apps no existe o no está Ready"; exit 1; }
  test "$(K -n flux-system get kustomization apps -o jsonpath='{.spec.sourceRef.name}/{.spec.path}/{.spec.prune}')" = "flux-system/./apps/saludo/true" || { echo "apps debe leer flux-system, ./apps/saludo, con prune: true"; exit 1; }
  test "$(K -n flux-system get kustomization apps -o jsonpath='{.spec.suspend}')" != true || { echo "apps está suspendida"; exit 1; }
  HEAD=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$URL" refs/heads/main | cut -f1); test -n "$HEAD" || exit 1
  K -n flux-system get kustomization apps -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || { echo "apps no aplicó el HEAD de Git"; exit 1; }
  test "$(K -n saludo get deploy saludo -o jsonpath='{.spec.replicas}')" -ge 2 || { echo "el Deployment saludo no tiene 2 o más réplicas"; exit 1; }
  test "$(K -n saludo get deploy saludo -o jsonpath='{.status.availableReplicas}')" = "$(K -n saludo get deploy saludo -o jsonpath='{.spec.replicas}')" || { echo "réplicas no disponibles"; exit 1; }
  K -n saludo get deploy saludo -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q '@sha256:[0-9a-f]\{64\}$' || { echo "la imagen no está fijada por digest"; exit 1; }
  K -n saludo get deploy saludo -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}' | grep -qx apps || { echo "el Deployment no lo gestiona la Kustomization apps"; exit 1; }
  MG=$(K -n saludo get deploy saludo -o jsonpath='{range .metadata.managedFields[*]}{.manager}{"\n"}{end}')
  echo "$MG" | grep -qx kustomize-controller || { echo "nadie de Flux escribió el objeto"; exit 1; }
  if echo "$MG" | grep -q '^kubectl'; then echo "alguien aplicó el objeto con kubectl; todo debe entrar por Git"; exit 1; fi
)

# ---------- 3. La deriva se corrige sola, en 60 s o menos de intervalo ----------
c_deriva() (
  IV=$(K -n flux-system get kustomization apps -o jsonpath='{.spec.interval}'); test -n "$IV" || { echo "no existe la Kustomization apps"; exit 1; }
  SEG=$(echo "$IV" | awk '{s=0; if (match($0,/[0-9]+h/)) s+=substr($0,RSTART,RLENGTH-1)*3600; if (match($0,/[0-9]+m/)) s+=substr($0,RSTART,RLENGTH-1)*60; if (match($0,/[0-9]+s/)) s+=substr($0,RSTART,RLENGTH-1); print s}')
  test "$SEG" -gt 0 -a "$SEG" -le 60 || { echo "el intervalo es $IV; debe ser de 60 s o menos"; exit 1; }
  test "$(K -n flux-system get kustomization apps -o jsonpath='{.spec.suspend}')" != true || { echo "apps está suspendida"; exit 1; }
  HEAD=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$URL" refs/heads/main | cut -f1)
  for i in $(seq 1 20); do K -n flux-system get kustomization apps -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" && break; sleep 3; done
  K -n flux-system get kustomization apps -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || { echo "apps no aplicó el HEAD; el intervalo debe entrar por Git, no por kubectl edit"; exit 1; }
  DESEADO=$(curl -fs "http://$GIP:3000/lab/fleet/raw/branch/main/apps/saludo/deployment.yaml" | awk '/^ *replicas:/{print $2; exit}'); test -n "$DESEADO" || exit 1
  K -n saludo scale deploy saludo --replicas=$((DESEADO+3)) >/dev/null || exit 1   # el verificador provoca la deriva
  T0=$(date +%s); OK=0
  for i in $(seq 1 60); do
    test "$(K -n saludo get deploy saludo -o jsonpath='{.spec.replicas}')" = "$DESEADO" && { OK=1; break; }
    sleep 3
  done
  test $OK = 1 || { echo "pasaron $(( $(date +%s)-T0 )) s y Flux no revirtió la deriva"; exit 1; }
  echo "deriva corregida en $(( $(date +%s)-T0 )) s con intervalo $IV"
)

# ---------- 4. El rollback es un git revert que sigue en la historia ----------
c_revert() (
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  GIT_TERMINAL_PROMPT=0 git clone -q "$URL" "$T/r" || exit 1; cd "$T/r"
  R=$(git log --format=%H --grep='^This reverts commit [0-9a-f]\{40\}' main | head -1)
  test -n "$R" || { echo "no hay ningún commit creado con git revert en main"; exit 1; }
  X=$(git show -s --format=%B "$R" | sed -n 's/^This reverts commit \([0-9a-f]\{40\}\).*/\1/p' | head -1)
  git merge-base --is-ancestor "$X" main || { echo "el commit revertido ya no está en la historia (se reescribió)"; exit 1; }
  git diff --name-only "$X^" "$X" | grep -q '^apps/' || { echo "el commit revertido no tocó apps/"; exit 1; }
  git diff --quiet "$X^" main -- apps/saludo || { echo "apps/saludo no volvió al estado anterior al cambio"; exit 1; }
  HEAD=$(git rev-parse main)
  for i in $(seq 1 30); do K -n flux-system get kustomization apps -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" && break; sleep 3; done
  K -n flux-system get kustomization apps -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || { echo "el clúster no aplicó el HEAD con el revert"; exit 1; }
  kubectl -n saludo rollout status deploy/saludo --timeout=90s >/dev/null 2>&1 || { echo "el despliegue no terminó"; exit 1; }
  test "$(K -n saludo get deploy saludo -o jsonpath='{.status.updatedReplicas}')" = "$(K -n saludo get deploy saludo -o jsonpath='{.spec.replicas}')" || { echo "réplicas sin actualizar"; exit 1; }
  if K -n saludo get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' | grep -Eq 'ImagePull|ErrImage'; then echo "quedan pods con error de imagen"; exit 1; fi
)

# ---------- 5. La compuerta rechaza lo inválido y deja pasar lo válido ----------
c_compuerta() (
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  cp -a "$W/fleet" "$T/r" && cd "$T/r" || exit 1
  git config user.name t; git config user.email t@example.com
  F=$(grep -rl '^kind: Deployment' apps | head -1); test -n "$F" || { echo "no hay Deployment bajo apps/"; exit 1; }
  sed -i -E 's/^( *replicas:).*/\1 "dos"/' "$F"
  if git commit -qam "cambio invalido 1" >/dev/null 2>&1; then echo "se aceptó un Deployment con replicas de tipo texto"; exit 1; fi
  git checkout -q -- "$F"
  sed -i '0,/^spec:/s//spec:\n  replicsa: 2/' "$F"
  if git commit -qam "cambio invalido 2" >/dev/null 2>&1; then echo "se aceptó un campo inexistente (replicsa)"; exit 1; fi
  git checkout -q -- "$F"
  sed -i -E 's/^( *replicas:).*/\1 3/' "$F"
  git commit -qam "cambio valido" >/dev/null 2>&1 || { echo "la compuerta rechazó un cambio válido, o no existe el gancho pre-commit"; exit 1; }
)

# ---------- 6. La firma es sobre el digest, y lo que nadie firmó no verifica ----------
c_cosign() (
  REG=localhost:5088
  dig() { curl -fsI -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' "http://$REG/v2/lab/$1/manifests/$2" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'; }
  V() { cosign verify --key "$W/llaves/cosign.pub" --insecure-ignore-tlog --allow-insecure-registry "$@" 2>/dev/null; }
  test -s "$W/llaves/cosign.pub" -a -s "$W/llaves/cosign.key" || { echo "faltan cosign.pub o cosign.key en $W/llaves"; exit 1; }
  if grep -rlq 'SIGSTORE PRIVATE KEY' "$W/fleet" 2>/dev/null; then echo "hay una llave privada dentro del repo"; exit 1; fi
  H=$(dig hola 1.0.0); I=$(dig intruso 1.0.0); test -n "$H" -a -n "$I" || { echo "el registro no responde"; exit 1; }
  OUT=$(V "$REG/lab/hola@$H") || { echo "la imagen hola@$H no verifica con tu llave pública"; exit 1; }
  echo "$OUT" | grep -q "\"docker-manifest-digest\":\"$H\"" || { echo "la firma no es sobre el digest $H"; exit 1; }
  if V "$REG/lab/intruso@$I" >/dev/null; then echo "la imagen intruso verifica sin haberla firmado"; exit 1; fi
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT; (cd "$T" && COSIGN_PASSWORD= cosign generate-key-pair >/dev/null 2>&1) || exit 1
  if cosign verify --key "$T/cosign.pub" --insecure-ignore-tlog --allow-insecure-registry "$REG/lab/hola@$H" >/dev/null 2>&1; then echo "verifica con una llave ajena"; exit 1; fi
)

# ---------- 7. OpenTofu: plan vacío, deriva detectada, apply la repara ----------
c_tofu() (
  cd "$W/tofu" || { echo "no existe $W/tofu"; exit 1; }
  export TF_IN_AUTOMATION=1
  grep -Eq 'version *= *"= *[0-9]+\.[0-9]+\.[0-9]+"' *.tf 2>/dev/null || { echo "la versión del proveedor no está fijada con ="; exit 1; }
  test -s .terraform.lock.hcl || { echo "falta .terraform.lock.hcl (tofu init)"; exit 1; }
  tofu state list 2>/dev/null | grep -q kubernetes_namespace_v1 || { echo "el estado no tiene el namespace; falta el apply"; exit 1; }
  test "$(K get ns iac-lab -o jsonpath='{.metadata.name}')" = iac-lab || { echo "no existe el namespace iac-lab"; exit 1; }
  test "$(K -n iac-lab get cm ajustes -o jsonpath='{.data.nivel}')" = produccion || { echo "el ConfigMap ajustes no dice nivel=produccion"; exit 1; }
  K get ns iac-lab -o jsonpath='{.metadata.labels}' | grep -q kustomize.toolkit && { echo "Flux y OpenTofu gestionan el mismo namespace"; exit 1; }
  tofu plan -detailed-exitcode -input=false >/dev/null 2>&1; test $? = 0 || { echo "el plan no está vacío; el clúster no coincide con el código"; exit 1; }
  K -n iac-lab patch cm ajustes --type merge -p '{"data":{"nivel":"manual"}}' >/dev/null || exit 1   # el verificador provoca la deriva
  tofu plan -detailed-exitcode -input=false >/dev/null 2>&1; test $? = 2 || { echo "el plan no detectó la deriva"; exit 1; }
  tofu apply -auto-approve -input=false >/dev/null 2>&1 || { echo "el apply no reparó la deriva"; exit 1; }
  test "$(K -n iac-lab get cm ajustes -o jsonpath='{.data.nivel}')" = produccion || { echo "la deriva sigue ahí"; exit 1; }
)

echo "Reto 1 (módulo 8, GitOps) en el clúster m08-gitops1"
chequeo "Flux se instaló desde Git: 4 controladores, fuente en Gitea, ruta clusters/m08, HEAD aplicado" c_flux
chequeo "La app saludo entró por Git: Kustomization apps con prune, imagen por digest, sin kubectl"     c_app
chequeo "Una edición a mano se deshace sola: intervalo de 60 s o menos, medido"                        c_deriva
chequeo "Rollback con git revert: el commit malo sigue en la historia, el clúster se recuperó"         c_revert
chequeo "La compuerta pre-commit rechaza tipo y campo inválidos y acepta un cambio válido"             c_compuerta
chequeo "cosign: hola firmada por digest, intruso y una llave ajena no verifican"                      c_cosign
chequeo "OpenTofu: plan vacío, deriva detectada con código 2 y reparada por apply"                     c_tofu
echo "Resultado: $OK/$TOTAL"
[ "$OK" = "$TOTAL" ]

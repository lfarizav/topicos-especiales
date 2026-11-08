#!/usr/bin/env bash
# Verificador del Reto y del Incidente (Paso 9 y Paso 10): califica el ESTADO FINAL, no los comandos que usaste.
# Uso:  bash "$MAT/verificar-reto.sh"          los 15 chequeos (Paso 9 + Paso 10)
#       bash "$MAT/verificar-reto.sh" --reto   solo los 13 chequeos del Paso 9
# No lo edites: el profesor corre su propia copia sobre tu clúster, y esta imprime su propia suma (Verificador:).
MODO=completo; [ "${1:-}" = "--reto" ] && MODO=reto
esta() { grep "$@" >/dev/null; }   # grep sin -q: con tuberías y pipefail, -q puede dar falsos negativos
export W="$HOME/lab-gitops-2" REG=127.0.0.1:5092 API="http://127.0.0.1:3092/api/v1"
export PATH="$W/bin:$PATH" KUBECONFIG="$W/kubeconfig"
export URL="http://$(cat "$W/gitea.ip"):3000/lab/fleet.git" CL=$(mktemp -d)
git clone -q "$URL" "$CL/f" 2>/dev/null
OK=0; TOTAL=0
chequeo() {  # $1 = descripcion, $2 = funcion que sale con 0 si el mundo esta bien
  TOTAL=$((TOTAL+1))
  if bash -c "$2" >/dev/null 2>&1; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1"; fi
}
digest() { curl -fsI -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' "http://$REG/v2/ruleta/manifests/$1" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'; }
firmada() { cosign verify --key "$W/llaves/cosign.pub" --insecure-ignore-tlog --allow-insecure-registry "$REG/ruleta@$1"; }
export D110=$(digest 1.1.0) D120=$(digest 1.2.0)

c_flux() { for d in source-controller kustomize-controller helm-controller notification-controller image-reflector-controller image-automation-controller; do
  [ "$(kubectl -n flux-system get deploy $d -o jsonpath='{.status.availableReplicas}')" = 1 ] || return 1; done; }
c_politica() { [ "$(kubectl -n flux-system get imagepolicy ruleta -o jsonpath='{.status.latestRef.tag}')" = 1.1.0 ]; }
c_rango() { R=$(kubectl -n flux-system get imagepolicy ruleta -o jsonpath='{.spec.policy.semver.range}')
  [ -n "$R" ] && [ "$R" != 1.x ] && grep -Eq "range: *\"?${R}\"?\$" "$CL/f/apps/ruleta/imagepolicy.yaml"; }
pods_ruleta() { kubectl -n ruleta get pods -l app=ruleta -o json | python3 -c 'import json,sys
for p in json.load(sys.stdin)["items"]:
    if p["metadata"].get("deletionTimestamp"): continue   # un pod que termina no cuenta
    cs=(p["status"].get("containerStatuses") or [{}])[0]
    print(p["spec"]["containers"][0]["image"], cs.get("imageID",""))'; }
c_pods() { [ "$(kubectl -n ruleta get deploy ruleta -o jsonpath='{.status.availableReplicas}')" = "$(kubectl -n ruleta get deploy ruleta -o jsonpath='{.spec.replicas}')" ] &&
  ! pods_ruleta | awk '{print $1}' | grep -qv ':1.1.0$'; }
c_digest() { pods_ruleta | awk '{print $2}' | grep -qv "$D110" && return 1
  firmada "$D110"; }
c_evidencia() { curl -fs "http://$REG/v2/ruleta/tags/list" | grep -q '"1.2.0"'; }
c_sin_firma() { ! firmada "$D120"; }
c_automatizacion() { [ "$(kubectl -n flux-system get imageupdateautomation ruleta -o jsonpath='{.spec.suspend}')" != true ] &&
  grep -q 'kind: ImageUpdateAutomation' "$CL/f/apps/ruleta/imageupdateautomation.yaml" && ! grep -q 'suspend: true' "$CL/f/apps/ruleta/imageupdateautomation.yaml"; }
c_git() { grep -q 'ruleta:1.1.0 # {"$imagepolicy"' "$CL/f/apps/ruleta/deployment.yaml"; }
c_aguanta() { TC=$(git -C "$CL/f" log -1 --format=%ct -- apps/ruleta)
  LR=$(date -d "$(kubectl -n flux-system get imageupdateautomation ruleta -o jsonpath='{.status.lastAutomationRunTime}')" +%s); [ "$LR" -ge $((TC+60)) ]; }
c_rbac() { [ "$(kubectl auth can-i patch deployments.apps -n tienda --as=system:serviceaccount:agentes:agente)" = no ]; }
c_proteccion() { curl -fs -u "lab:$GITEA_PASS" "$API/repos/lab/fleet/branch_protections/main" | python3 -c 'import json,sys;b=json.load(sys.stdin);sys.exit(0 if b.get("merge_whitelist_usernames")==["lab"] and b.get("push_whitelist_usernames")==["lab"] and b.get("required_approvals",0)>=1 else 1)'; }
c_catalogo() { [ "$(kubectl -n tienda get deploy catalogo -o jsonpath='{.status.availableReplicas}')" = 1 ]; }
export -f firmada pods_ruleta c_flux c_politica c_rango c_pods c_digest c_evidencia c_sin_firma c_automatizacion c_git c_aguanta c_rbac c_proteccion c_catalogo

chequeo "Los seis controladores de Flux están disponibles" c_flux
chequeo "La ImagePolicy resuelve 1.1.0, la versión más nueva FIRMADA" c_politica
chequeo "El rango de la política ya no es 1.x y está escrito en Git (no en el clúster)" c_rango
chequeo "Todos los pods corren ruleta:1.1.0 y el Deployment está completo" c_pods
chequeo "Los pods corren el digest que firmaste, verificado con cosign.pub" c_digest
chequeo "La etiqueta 1.2.0 sigue en el registro (no se borró la evidencia)" c_evidencia
chequeo "La 1.2.0 sigue SIN firma (no se firmó para taparla)" c_sin_firma
chequeo "La automatización existe, está en Git y no está suspendida" c_automatizacion
chequeo "Git (main) fija 1.1.0 en el Deployment" c_git
chequeo "Pasaron 2 intervalos de la automatización desde el último commit de apps/ruleta" c_aguanta
chequeo "El agente sigue sin poder parchear Deployments (el RBAC no se tocó)" c_rbac
chequeo "La rama main sigue protegida: solo lab empuja y fusiona, con 1 aprobación" c_proteccion
chequeo "catalogo (Paso 8) sigue disponible: el reto no deshizo el trabajo anterior" c_catalogo

# ---------------------------------------------------------------------------------------------
# PASO 10: el incidente en producción. Solo en modo completo. Dos chequeos que comparten una evaluación:
#   14 = el sistema volvió al estado correcto (en Git Y en el clúster)
#   15 = la corrección es legítima (ticket íntegro, una sola corrida, historial y protección intactos, informe escrito)
# Los mensajes de [FALLA] describen el ESTADO que se observa; nunca dicen qué comando teclear.
# ---------------------------------------------------------------------------------------------
INC="$W/.incidente"
leer() { grep -m1 "^$1=" "$INC" 2>/dev/null | cut -d= -f2-; }
# Objetos de una ruta del repositorio, ya renderizada por kustomize y convertida a JSON (uno detrás de otro)
render() { ( cd "$CL/f" && kubectl kustomize "$1" 2>/dev/null ) | kubectl apply --dry-run=client --validate=false -o json -f - 2>/dev/null; }
# Lee JSON concatenado de stdin y evalúa un modo; imprime el motivo si el estado está mal y sale 1
objeto_mal() { python3 -c '
import json,sys
modo=sys.argv[1]; s=sys.stdin.read(); dec=json.JSONDecoder(); i=0; objs=[]
while True:
    while i<len(s) and s[i].isspace(): i+=1
    if i>=len(s): break
    o,i=dec.raw_decode(s,i); objs.extend(o["items"] if o.get("kind")=="List" else [o])
def mal(m): print(m); sys.exit(1)
if modo=="rbac":
    roles=[o for o in objs if o.get("kind")=="ClusterRole" and o["metadata"]["name"]=="agente-lectura"]
    if not roles: mal("en Git no existe el ClusterRole agente-lectura")
    for r in roles:
        for ru in r.get("rules") or []:
            v=set(ru.get("verbs") or []); res=set(ru.get("resources") or [])
            if v-{"get","list","watch"}: mal("en Git, el rol del agente concede verbos de escritura: %s sobre %s" % (sorted(v-{"get","list","watch"}),sorted(res)))
            if res & {"secrets","pods/exec","*"}: mal("en Git, el rol del agente alcanza recursos prohibidos: %s" % sorted(res & {"secrets","pods/exec","*"}))
    for b in objs:
        if b.get("kind") in ("ClusterRoleBinding","RoleBinding"):
            for su in b.get("subjects") or []:
                if su.get("kind")=="ServiceAccount" and su.get("name")=="agente" and b["roleRef"]["name"]!="agente-lectura":
                    mal("en Git, la cuenta del agente está atada a otro rol: %s" % b["roleRef"]["name"])
elif modo=="sm":
    sm=[o for o in objs if o.get("kind")=="ServiceMonitor" and o["metadata"]["name"]=="ruleta"]
    if not sm: mal("en Git no existe el ServiceMonitor ruleta")
    sp=sm[0]["spec"]; sel=(sp.get("selector") or {}).get("matchLabels")
    if sel!={"app":"ruleta"}: mal("en Git, el ServiceMonitor selecciona Services con %s, y el Service de la ruleta no tiene esas etiquetas" % json.dumps(sel))
    ep=(sp.get("endpoints") or [{}])[0]
    if ep.get("port")!="http" or ep.get("path")!="/metrics": mal("en Git, el ServiceMonitor ya no extrae http:/metrics")
elif modo=="svc":
    dep=[o for o in objs if o.get("kind")=="Deployment" and o["metadata"]["name"]=="catalogo"]
    sv=[o for o in objs if o.get("kind")=="Service" and o["metadata"]["name"]=="catalogo"]
    if not dep: mal("en Git no existe el Deployment catalogo")
    if not sv: mal("en Git no existe el Service catalogo (borrarlo no es arreglarlo)")
    lab=dep[0]["spec"]["template"]["metadata"]["labels"]; sel=sv[0]["spec"].get("selector") or {}
    if not sel or any(lab.get(k)!=v for k,v in sel.items()): mal("en Git, el Service catalogo selecciona pods con %s y los pods del Deployment tienen %s" % (json.dumps(sel),json.dumps(lab)))
' "$1"; }

# Estado vivo del clúster (después de que Flux reconcilia). Imprime un motivo y sale 1 si algo está mal.
vivo_mal() {
  local k v n
  for k in agentes monitoring-configs tienda ruleta; do
    [ "$(kubectl -n flux-system get kustomization $k -o jsonpath='{.spec.suspend}' 2>/dev/null)" != true ] || { echo "la Kustomization $k de Flux está suspendida (apagar el control no es arreglar)"; return 1; }
    [ "$(kubectl -n flux-system get kustomization $k -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = True ] || { echo "la Kustomization $k de Flux aún no está Ready con lo último de Git"; return 1; }
  done
  SA=system:serviceaccount:agentes:agente
  [ "$(kubectl auth can-i get pods -n tienda --as=$SA 2>/dev/null)" = yes ] || { echo "el agente ya no puede leer pods en tienda (se le quitó lo que sí debía tener)"; return 1; }
  for v in "patch deployments.apps" "update deployments.apps" "delete pods" "get secrets" "create pods/exec"; do
    [ "$(kubectl auth can-i $v -n tienda --as=$SA 2>/dev/null)" = no ] || { echo "en el clúster, el agente todavía puede: $v (namespace tienda)"; return 1; }
  done
  [ -n "$(kubectl -n tienda get endpoints catalogo -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)" ] || { echo "en el clúster, el Service catalogo no tiene ningún endpoint (ningún pod coincide con su selector)"; return 1; }
  kubectl -n tienda get service catalogo -o jsonpath='{.spec.selector.app}' 2>/dev/null | esta -x catalogo || { echo "en el clúster, el Service catalogo no selecciona app=catalogo"; return 1; }
  n=$(k8sgpt analyze --filter=Pod,Service --namespace=tienda --output=json --no-cache 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("problems",99))' 2>/dev/null) || n=99
  [ "$n" = 0 ] || { echo "K8sGPT sigue reportando $n problema(s) en el namespace tienda"; return 1; }
  [ "$(kubectl -n monitoring get servicemonitor ruleta -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)" = ruleta ] || { echo "en el clúster, el ServiceMonitor ruleta no selecciona app=ruleta"; return 1; }
  n=$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=count(up%7Bnamespace%3D%22ruleta%22%7D%3D%3D1)" 2>/dev/null | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"];print(r[0]["value"][1] if r else 0)' 2>/dev/null) || n=0
  [ "$n" = 2 ] || { echo "Prometheus ve $n objetivos de la ruleta con up==1 (se esperan 2)"; return 1; }
  return 0
}

inc_eval() {   # llena MA (chequeo 14), MB (chequeo 15) y HUELLA; vacío = bien
  MA=""; MB=""; HUELLA=""
  local PL CMJ M TOKEN COMMIT INCID REF RC CMH CMC CMR N H G
  PL=$(git -C "$CL/f" log --author=plataforma@example.com --format=%H 2>/dev/null | head -n 1)
  CMJ=$(kubectl -n agentes get configmap incidente -o json 2>/dev/null) || CMJ=""
  if [ ! -s "$INC" ]; then
    if [ -n "$PL" ] || [ -n "$CMJ" ]; then M="falta $INC: el incidente ya se había inyectado y el archivo de su ticket ya no está (no se vale borrarlo)"
    else M="no ejecutaste preparar-incidente.sh: no hay ningún incidente abierto"; fi
    MA="$M"; MB="$M"; return 0
  fi
  TOKEN=$(leer TOKEN); COMMIT=$(leer COMMIT); INCID=$(leer INC); REF=$(leer REINTENTOS); REF=${REF:-0}
  # ---- chequeo 15: legitimidad
  if [ -z "$CMJ" ]; then MB="falta el registro del incidente en el clúster (ConfigMap agentes/incidente); no se vale borrarlo"
  else
    CMH=$(echo "$CMJ" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"].get("hash",""))')
    CMC=$(echo "$CMJ" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"].get("commit",""))')
    CMR=$(echo "$CMJ" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"].get("reintentos","0"))')
    H=$(printf %s "$TOKEN" | sha256sum | cut -d' ' -f1)
    N=$REF; [ "$CMR" -gt "$N" ] 2>/dev/null && N=$CMR
    if [ "$H" != "$CMH" ] || [ "$COMMIT" != "$CMC" ] || [ "$INCID" != "INC-${H:0:6}" ]; then MB="el ticket de $INC no corresponde al incidente registrado en el clúster (archivo alterado o de otra corrida)"
    elif [ "$N" -gt 0 ]; then MB="volviste a ejecutar preparar-incidente.sh ($N intento/s); el incidente es de una sola corrida"
    elif ! git -C "$CL/f" merge-base --is-ancestor "$COMMIT" HEAD 2>/dev/null; then MB="el commit sospechoso ya no está en el historial de main (se reescribió la historia)"
    elif [ "$(git -C "$CL/f" log --author=plataforma@example.com --format=%H | wc -l)" != 1 ]; then MB="el historial de main no tiene exactamente un commit del equipo de plataforma (se reescribió la historia)"
    elif ! curl -fs -u "lab:$GITEA_PASS" "$API/repos/lab/fleet/branch_protections/main" | python3 -c 'import json,sys;b=json.load(sys.stdin);sys.exit(0 if b.get("merge_whitelist_usernames")==["lab"] and b.get("push_whitelist_usernames")==["lab"] and b.get("required_approvals",0)>=1 and not b.get("enable_force_push") and b.get("enable_push") else 1)' >/dev/null 2>&1; then MB="la protección de main no es la del montaje (empuje y fusión solo de lab, 1 aprobación, sin empuje forzado)"
    elif [ ! -s "$CL/f/incidentes/$INCID.md" ]; then MB="en main no hay un informe incidentes/$INCID.md"
    elif ! esta -F "$INCID" "$CL/f/incidentes/$INCID.md" || ! esta -F "${COMMIT:0:7}" "$CL/f/incidentes/$INCID.md" || [ "$(grep -c . "$CL/f/incidentes/$INCID.md")" -lt 5 ]; then MB="el informe incidentes/$INCID.md no cita el ID del ticket y el SHA corto (7) del commit sospechoso, o tiene menos de 5 líneas con contenido"
    fi
  fi
  # ---- chequeo 14: estado correcto (primero Git, que es inmediato; después el clúster, que espera a Flux)
  M=$(render apps/agentes | objeto_mal rbac) || { MA="$M"; return 0; }
  M=$(render monitoring/configs | objeto_mal sm) || { MA="$M"; return 0; }
  M=$(render apps/tienda | objeto_mal svc) || { MA="$M"; return 0; }
  G=$((SECONDS+150))
  while :; do M=$(vivo_mal) && break; [ $SECONDS -ge $G ] && { MA="$M"; break; }; sleep 5; done
  if [ -z "$MA" ] && [ -z "$MB" ]; then HUELLA=$(printf %s%s "$TOKEN" "$(kubectl get ns kube-system -o jsonpath='{.metadata.uid}')" | sha256sum | cut -c1-12); fi
  return 0
}
chequeo_inc() {  # $1 = descripcion, $2 = motivo (vacío = bien)
  TOTAL=$((TOTAL+1))
  if [ -z "$2" ]; then echo "  [OK]    $1"; OK=$((OK+1)); else echo "  [FALLA] $1"; echo "          motivo: $2"; fi
}
if [ "$MODO" = completo ]; then
  inc_eval
  chequeo_inc "Incidente (Paso 10): el sistema volvió al estado correcto, en Git y en el clúster" "$MA"
  chequeo_inc "Incidente (Paso 10): la corrección es legítima (ticket íntegro, una sola corrida, historial y protección intactos, informe escrito)" "$MB"
fi
rm -rf "$CL"
echo "Resultado: $OK/$TOTAL"
if [ "$MODO" = completo ]; then
  echo "Huella: ${HUELLA:-(se calcula solo con el incidente resuelto)}"
  echo "Verificador: $(sha256sum "${BASH_SOURCE[0]}" | cut -c1-12)"
fi
[ "$OK" = "$TOTAL" ]

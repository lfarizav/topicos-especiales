. "$(dirname "$0")/_comun.sh"
SA=system:serviceaccount:agentes:agente
si() { [ "$(K auth can-i "$@" --as=$SA)" = yes ] || falla "el agente DEBE poder: $*"; }
no() { [ "$(K auth can-i "$@" --as=$SA)" = no ] || falla "el agente NO debe poder: $*"; }
si get pods -n tienda; si list pods -n tienda; si list deployments.apps -n tienda; si list events -n tienda; si get replicasets.apps -n tienda
no create deployments.apps -n tienda; no patch deployments.apps -n tienda; no delete pods -n tienda; no delete deployments.apps -n tienda
no get secrets -n tienda; no get secrets -n flux-system; no create pods/exec -n tienda; no patch deployments.apps -n ruleta; no '*' '*' --all-namespaces
python3 - <<'PY' || falla "el agente esta ligado a un rol de escritura o a uno que no gestiona Flux"
import json,subprocess,os
def j(*a): return json.loads(subprocess.check_output(["kubectl",*a,"-o","json"]))
bad=0
items=j("get","clusterrolebindings")["items"]+j("get","rolebindings","-A")["items"]
mine=[i for i in items if any(s.get("kind")=="ServiceAccount" and s.get("name")=="agente" and s.get("namespace")=="agentes" for s in i.get("subjects") or [])]
if not mine: raise SystemExit(1)
for i in mine:
    if i["roleRef"]["name"] in ("cluster-admin","admin","edit"): raise SystemExit(1)
    if "kustomize.toolkit.fluxcd.io/name" not in (i["metadata"].get("labels") or {}): raise SystemExit(1)
PY
[ -n "$(K -n agentes get sa agente -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}')" ] || falla "la ServiceAccount no la gestiona una Kustomization de Flux; el RBAC entra por Git"
echo ok

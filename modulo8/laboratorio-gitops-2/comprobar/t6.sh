. "$(dirname "$0")/_comun.sh"
[ "$(K -n flux-system get imagepolicy ruleta -o jsonpath='{.status.latestRef.tag}')" = 1.0.0 ] || falla "la politica no resuelve 1.0.0 (el rollback se hace fijando la politica)"
curl -fs "http://$REG/v2/ruleta/tags/list" | grep -q '"1.1.0"' || falla "borro la etiqueta 1.1.0 del registro; eso es borrar evidencia, no revertir"
[ "$(K -n flux-system get imageupdateautomation ruleta -o jsonpath='{.spec.suspend}')" != true ] || falla "suspendio la automatizacion: eso apaga el control, no revierte"
clonar; F="$CL/f/apps/ruleta"
[ -f "$F/imageupdateautomation.yaml" ] && ! grep -q 'suspend: true' "$F/imageupdateautomation.yaml" || falla "la automatizacion fue borrada o suspendida en Git"
RNG=$(K -n flux-system get imagepolicy ruleta -o jsonpath='{.spec.policy.semver.range}')
[ -n "$RNG" ] && [ "$RNG" != 1.x ] && grep -q "range: *\"\?$(printf '%s' "$RNG" | sed 's/[.*[\^$]/\\&/g')\"\?" "$F/imagepolicy.yaml" || falla "la politica fijada no esta en Git (range del clúster: '$RNG')"
grep -q 'ruleta:1.0.0 # {"$imagepolicy"' "$F/deployment.yaml" || falla "Git (main) no tiene 1.0.0 en el Deployment"
HEAD=$(git -C "$CL/f" rev-parse HEAD); TC=$(git -C "$CL/f" log -1 --format=%ct -- apps/ruleta)
K -n flux-system get kustomization ruleta -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || falla "ruleta no aplico el HEAD de Git; espere un intervalo"
INT=$(K -n flux-system get imageupdateautomation ruleta -o jsonpath='{.spec.interval}'); S=${INT%s}; [ "$S" -gt 0 ] 2>/dev/null || S=30
LR=$(date -d "$(K -n flux-system get imageupdateautomation ruleta -o jsonpath='{.status.lastAutomationRunTime}')" +%s 2>/dev/null || echo 0)
NEED=$((TC + 2*S))
[ "$LR" -ge "$NEED" ] || falla "todavia no pasaron 2 intervalos de la automatizacion despues del ultimo commit; espere $((NEED-LR)) s y repita (el rollback debe SOBREVIVIR a la automatizacion)"
R=$(K -n ruleta get deploy ruleta -o jsonpath='{.spec.replicas}')
[ "$(K -n ruleta get deploy ruleta -o jsonpath='{.status.availableReplicas}')" = "$R" ] || falla "replicas no disponibles"
pods_ruleta | awk '{print $1}' | grep -qv ':1.0.0$' && falla "hay pods que no corren 1.0.0"
K get --raw /api/v1/namespaces/ruleta/services/ruleta:80/proxy/static/tema.css | grep -q -- '--fondo: #000000' || falla "la pagina servida no es negra"
echo ok

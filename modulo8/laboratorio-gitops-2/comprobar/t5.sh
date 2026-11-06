. "$(dirname "$0")/_comun.sh"
[ "$(K -n flux-system get imagepolicy ruleta -o jsonpath='{.status.latestRef.tag}')" = 1.1.0 ] || falla "la ImagePolicy no resuelve 1.1.0"
D=$(digest ruleta 1.1.0); [ -n "$D" ] || falla "el registro no tiene ruleta:1.1.0"
cosign_ok ruleta "$D" || falla "ruleta:1.1.0 ($D) no verifica con cosign por digest"
clonar
git -C "$CL/f" log --format='%an|%s' | grep -E '^fluxcdbot\|.*1\.1\.0' >/dev/null || falla "no hay commit de fluxcdbot que mencione 1.1.0 (lo debe hacer la automatizacion, no usted)"
git -C "$CL/f" show HEAD:apps/ruleta/deployment.yaml | grep -q 'ruleta:1.1.0 # {"$imagepolicy"' || falla "Git (main) no fija 1.1.0 en el Deployment"
R=$(K -n ruleta get deploy ruleta -o jsonpath='{.spec.replicas}')
[ "$(K -n ruleta get deploy ruleta -o jsonpath='{.status.availableReplicas}')" = "$R" ] || falla "replicas no disponibles"
IMGS=$(pods_ruleta)
[ "$(echo "$IMGS" | wc -l)" -ge 2 ] || falla "se esperaban 2 o mas pods"
echo "$IMGS" | while read -r img id; do [ "$img" = gitops2-registry:5000/ruleta:1.1.0 ] || exit 1; done || falla "hay pods que no corren 1.1.0"
echo "$IMGS" | grep -q "$D" || falla "ningun pod corre el digest firmado $D"
K get --raw /api/v1/namespaces/ruleta/services/ruleta:80/proxy/static/tema.css | grep -q -- '--fondo: #ffffff' || falla "la pagina servida no es blanca"
echo ok

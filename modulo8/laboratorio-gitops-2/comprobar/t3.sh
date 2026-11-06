. "$(dirname "$0")/_comun.sh"
for d in source-controller kustomize-controller helm-controller notification-controller image-reflector-controller image-automation-controller; do
  [ "$(K -n flux-system get deploy $d -o jsonpath='{.status.availableReplicas}')" = 1 ] || falla "$d no esta disponible (bootstrap sin --components-extra?)"
done
[ "$(K -n flux-system get gitrepository flux-system -o jsonpath='{.spec.url}')" = "$URL" ] || falla "la fuente no apunta a $URL"
[ "$(K -n flux-system get kustomization flux-system -o jsonpath='{.spec.path}')" = ./clusters/m08 ] || falla "flux-system debe leer ./clusters/m08"
for k in flux-system ruleta; do
  [ "$(K -n flux-system get kustomization $k -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] || falla "Kustomization $k no esta Ready"
  [ "$(K -n flux-system get kustomization $k -o jsonpath='{.spec.suspend}')" != true ] || falla "Kustomization $k suspendida"
done
HEAD=$(GIT_TERMINAL_PROMPT=0 git ls-remote "$URL" refs/heads/main | cut -f1)
K -n flux-system get kustomization ruleta -o jsonpath='{.status.lastAppliedRevision}' | grep -q "$HEAD" || falla "ruleta no aplico el HEAD de Git ($HEAD); espere un intervalo"
[ "$(K -n flux-system get imagerepository ruleta -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] || falla "ImageRepository no Ready"
[ "$(K -n flux-system get imagepolicy ruleta -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] || falla "ImagePolicy no Ready"
clonar; grep -q '"$imagepolicy": "flux-system:ruleta"' "$CL/f/apps/ruleta/deployment.yaml" || falla "el Deployment perdio el marcador \$imagepolicy"
R=$(K -n ruleta get deploy ruleta -o jsonpath='{.spec.replicas}'); [ "$R" -ge 2 ] || falla "ruleta debe tener 2 o mas replicas"
[ "$(K -n ruleta get deploy ruleta -o jsonpath='{.status.availableReplicas}')" = "$R" ] || falla "replicas de ruleta no disponibles"
K -n ruleta get deploy ruleta -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q '^gitops2-registry:5000/ruleta:' || falla "la imagen no sale del registro local"
MG=$(K -n ruleta get deploy ruleta -o jsonpath='{range .metadata.managedFields[*]}{.manager}{"\n"}{end}')
echo "$MG" | grep -qx kustomize-controller || falla "nadie de Flux escribio el Deployment"
! echo "$MG" | grep -q '^kubectl' || falla "alguien aplico el Deployment con kubectl; todo entra por Git"
K get --raw /api/v1/namespaces/ruleta/services/ruleta:80/proxy/healthz | grep -q '"estado":"ok"' || falla "la ruleta no responde /healthz"
echo ok

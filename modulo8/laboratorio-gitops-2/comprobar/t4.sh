. "$(dirname "$0")/_comun.sh"
for k in monitoring-controllers monitoring-configs; do
  [ "$(K -n flux-system get kustomization $k -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] || falla "Kustomization $k no esta Ready (la pila tarda varios minutos)"
done
[ "$(K -n monitoring get deploy kube-prometheus-stack-grafana -o jsonpath='{.status.availableReplicas}')" = 1 ] || falla "Grafana no esta disponible"
K -n monitoring get configmap -l grafana_dashboard=1 -o name | grep -q ruleta-grafana-dashboard || falla "falta el panel de la ruleta para Grafana"
P=/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/query
UP=$(K get --raw "$P?query=$(python3 -c 'import urllib.parse;print(urllib.parse.quote("count(up{namespace=\"ruleta\"}==1)"))')" | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"];print(r[0]["value"][1] if r else 0)')
[ "$UP" -ge 2 ] || falla "Prometheus ve $UP objetivos de la ruleta con up==1 (se esperan 2): ServiceMonitor mal o sin aplicar"
INFO=$(K get --raw "$P?query=ruleta_info" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["data"]["result"]))')
[ "$INFO" -ge 1 ] || falla "la metrica ruleta_info no llega a Prometheus"
echo ok

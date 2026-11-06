#!/bin/bash
# Lo corre el HUMANO (operador): crea el kubeconfig del agente con un token de vida corta de SU ServiceAccount.
# El agente nunca recibe el kubeconfig de administrador.
set -euo pipefail
W="$HOME/lab-gitops-2"; export PATH="$W/bin:$PATH"
ADM="$W/kubeconfig"
TOKEN=$(kubectl --kubeconfig "$ADM" -n agentes create token agente --duration=1h)
SERVER=$(kubectl --kubeconfig "$ADM" config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl --kubeconfig "$ADM" config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$W/llaves/ca.crt"
K="$W/agente.kubeconfig"; rm -f "$K"
kubectl --kubeconfig "$K" config set-cluster gitops2 --server "$SERVER" --certificate-authority "$W/llaves/ca.crt" --embed-certs >/dev/null
kubectl --kubeconfig "$K" config set-credentials agente --token "$TOKEN" >/dev/null
kubectl --kubeconfig "$K" config set-context agente --cluster gitops2 --user agente >/dev/null
kubectl --kubeconfig "$K" config use-context agente >/dev/null
chmod 600 "$K"
echo "kubeconfig del agente listo: $K"

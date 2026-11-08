#!/bin/bash
# Paso 10 del Laboratorio 2 (Módulo 8): abre un incidente en producción SOBRE el sistema que dejó el Paso 9.
# Se corre UNA sola vez por montaje: la repetición queda registrada y el verificador la castiga.
# La inyección va en una carga opaca (cortesía para que usted investigue en vez de leer la respuesta;
# no es ocultamiento real: el commit sospechoso está en el historial de Git, que es donde se investiga).
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
W="$HOME/lab-gitops-2"; INC="$W/.incidente"
esta() { grep "$@" >/dev/null; }
: "${GITEA_PASS:?haga export GITEA_PASS=<la misma contrasena del montaje> antes}"
test -f "$W/env.sh" || { echo "ERROR: no existe $W/env.sh; monte el laboratorio y llegue al final del Paso 9" >&2; exit 1; }
. "$W/env.sh"

# 1. Una sola corrida: si ya hay (o hubo) un incidente, se rechaza y se anota el intento
PREVIO=""
if [ -s "$INC" ]; then PREVIO=archivo; fi
if kubectl -n agentes get configmap incidente >/dev/null 2>&1; then PREVIO=${PREVIO:-cluster}; fi
if [ -n "$(git -C "$W/fleet" fetch -q origin 2>/dev/null; git -C "$W/fleet" log origin/main --author=plataforma@example.com --format=%H 2>/dev/null | head -n 1)" ]; then PREVIO=${PREVIO:-historial}; fi
if [ -n "$PREVIO" ]; then
  if [ -s "$INC" ]; then N=$(grep -m1 '^REINTENTOS=' "$INC" | cut -d= -f2); sed -i "s/^REINTENTOS=.*/REINTENTOS=$((N+1))/" "$INC"; fi
  C=$(kubectl -n agentes get configmap incidente -o jsonpath='{.data.reintentos}' 2>/dev/null || true)
  kubectl -n agentes patch configmap incidente --type merge -p "{\"data\":{\"reintentos\":\"$(( ${C:-0} + 1 ))\"}}" >/dev/null 2>&1 || true
  echo "Ya hay un incidente abierto (o ya se abrió uno en este montaje). Este script no se repite y este intento quedó registrado." >&2
  echo "Para empezar de cero con otro incidente: bash $AQUI/desmontar.sh y luego montar.sh." >&2
  exit 4
fi

# 2. El punto de partida es el Paso 9 terminado: los 13 chequeos del reto, en verde
SAL=$(bash "$AQUI/verificar-reto.sh" --reto || true)
if ! echo "$SAL" | esta -x 'Resultado: 13/13'; then
  echo "$SAL" | grep -E 'FALLA|Resultado' >&2 || true
  echo "ERROR: el incidente se abre sobre el Paso 9 terminado. Lleve primero el reto a 13/13 y vuelva a correr este script." >&2; exit 2
fi
for k in agentes tienda monitoring-configs; do kubectl -n flux-system get kustomization $k >/dev/null 2>&1 || { echo "ERROR: falta la Kustomization $k (pasos 4, 7 y 8)" >&2; exit 2; }; done

# 3. Ficha del incidente de ESTA corrida (aleatoria; nunca se escribe dentro del repositorio)
TOKEN=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
HASH=$(printf %s "$TOKEN" | sha256sum | cut -d' ' -f1); ID="INC-${HASH:0:6}"
echo 'aW1wb3J0IGJhc2U2NCwganNvbiwgcmUsIHN5cywgdXJsbGliLnJlcXVlc3QKIyBhcmd2OiBBUEkgdXN1YXJpbyBjbGF2ZSB0b2tlbiByYW1hCmFwaSwgdXNyLCBwdywgdG9rID0gc3lzLmFyZ3ZbMTo1XQphdXRoID0gIkJhc2ljICIgKyBiYXNlNjQuYjY0ZW5jb2RlKGYie3Vzcn06e3B3fSIuZW5jb2RlKCkpLmRlY29kZSgpCmRlZiBsbGFtYXIobWV0LCBydXRhLCBjdWVycG89Tm9uZSk6CiAgICByID0gdXJsbGliLnJlcXVlc3QuUmVxdWVzdChhcGkgKyBydXRhLCBtZXRob2Q9bWV0LCBkYXRhPShqc29uLmR1bXBzKGN1ZXJwbykuZW5jb2RlKCkgaWYgY3VlcnBvIGlzIG5vdCBOb25lIGVsc2UgTm9uZSksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBoZWFkZXJzPXsiQXV0aG9yaXphdGlvbiI6IGF1dGgsICJDb250ZW50LVR5cGUiOiAiYXBwbGljYXRpb24vanNvbiJ9KQogICAgd2l0aCB1cmxsaWIucmVxdWVzdC51cmxvcGVuKHIpIGFzIGY6IHJldHVybiBqc29uLmxvYWQoZikKaW1wb3J0IGhhc2hsaWIKaCA9IGhhc2hsaWIuc2hhMjU2KHRvay5lbmNvZGUoKSkuaGV4ZGlnZXN0KCkKcjEsIHIyLCBleCA9IGhbODoxMl0sIGhbMTY6MjBdLCBpbnQoaFsyNDoyNl0sIDE2KSAlIDMKZGVmIGxlZXIocCk6CiAgICBkID0gbGxhbWFyKCJHRVQiLCBmIi9yZXBvcy9sYWIvZmxlZXQvY29udGVudHMve3B9P3JlZj1tYWluIikKICAgIHJldHVybiBiYXNlNjQuYjY0ZGVjb2RlKGRbImNvbnRlbnQiXSkuZGVjb2RlKCksIGRbInNoYSJdCmRlZiB1bm8odHh0LCB2aWVqbywgbnVldm8sIHApOgogICAgaWYgdHh0LmNvdW50KHZpZWpvKSAhPSAxOiBzeXMuZXhpdChmIk5PLUVOQ0FKQSB7cH06IGVsIGFyY2hpdm8geWEgbm8gdGllbmUgbGEgZm9ybWEgcXVlIGRlamFyb24gbG9zIHBhc29zIGFudGVyaW9yZXMiKQogICAgcmV0dXJuIHR4dC5yZXBsYWNlKHZpZWpvLCBudWV2bykKZXh0cmEgPSBbCiAiICAtIGFwaUdyb3VwczogW1wiXCJdXG4gICAgcmVzb3VyY2VzOiBbc2VjcmV0c11cbiAgICB2ZXJiczogW2dldCwgbGlzdF1cbiIsCiAiICAtIGFwaUdyb3VwczogW1wiXCJdXG4gICAgcmVzb3VyY2VzOiBbcG9kcy9leGVjXVxuICAgIHZlcmJzOiBbY3JlYXRlXVxuIiwKICIgIC0gYXBpR3JvdXBzOiBbXCJcIl1cbiAgICByZXNvdXJjZXM6IFtwb2RzXVxuICAgIHZlcmJzOiBbZGVsZXRlXVxuIl1bZXhdCnJiYWMsIHMxID0gbGVlcigiYXBwcy9hZ2VudGVzL3JiYWMueWFtbCIpCnJiYWMgPSB1bm8ocmJhYywgIiAgICByZXNvdXJjZXM6IFtpbmdyZXNzZXMsIG5ldHdvcmtwb2xpY2llc11cbiAgICB2ZXJiczogW2dldCwgbGlzdCwgd2F0Y2hdXG4iLAogICIgICAgcmVzb3VyY2VzOiBbaW5ncmVzc2VzLCBuZXR3b3JrcG9saWNpZXNdXG4gICAgdmVyYnM6IFtnZXQsIGxpc3QsIHdhdGNoXVxuICAtIGFwaUdyb3VwczogW2FwcHNdXG4gICAgcmVzb3VyY2VzOiBbZGVwbG95bWVudHNdXG4gICAgdmVyYnM6IFtwYXRjaCwgdXBkYXRlXVxuIiArIGV4dHJhLCAicmJhYyIpCnNtLCBzMiA9IGxlZXIoIm1vbml0b3JpbmcvY29uZmlncy9zZXJ2aWNlbW9uaXRvci1ydWxldGEueWFtbCIpCnNtID0gdW5vKHNtLCAibWF0Y2hMYWJlbHM6IHthcHA6IHJ1bGV0YX0iLCAibWF0Y2hMYWJlbHM6IHthcHA6IHJ1bGV0YS0lc30iICUgcjEsICJzbSIpCmt1LCBzMyA9IGxlZXIoImFwcHMvdGllbmRhL2t1c3RvbWl6YXRpb24ueWFtbCIpCmt1ID0gdW5vKGt1LCAiICAtIGRlcGxveW1lbnQueWFtbFxuIiwgIiAgLSBkZXBsb3ltZW50LnlhbWxcbiAgLSBzZXJ2aWNlLnlhbWxcbiIsICJ0aWVuZGEiKQpzdmMgPSAoImFwaVZlcnNpb246IHYxXG5raW5kOiBTZXJ2aWNlXG5tZXRhZGF0YTpcbiAgbmFtZTogY2F0YWxvZ29cbiAgbmFtZXNwYWNlOiB0aWVuZGFcbiAgbGFiZWxzOiB7YXBwOiBjYXRhbG9nb31cbnNwZWM6XG4iCiAgICAgICAiICBzZWxlY3Rvcjoge2FwcDogY2F0YWxvZ28tJXN9XG4gIHBvcnRzOlxuICAgIC0ge25hbWU6IGh0dHAsIHBvcnQ6IDgwLCB0YXJnZXRQb3J0OiA4MDgwfVxuIiAlIHIyKQpiID0gbGFtYmRhIHQ6IGJhc2U2NC5iNjRlbmNvZGUodC5lbmNvZGUoKSkuZGVjb2RlKCkKYXUgPSB7Im5hbWUiOiAiRXF1aXBvIHBsYXRhZm9ybWEiLCAiZW1haWwiOiAicGxhdGFmb3JtYUBleGFtcGxlLmNvbSJ9CnJlcyA9IGxsYW1hcigiUE9TVCIsICIvcmVwb3MvbGFiL2ZsZWV0L2NvbnRlbnRzIiwgeyJicmFuY2giOiAibWFpbiIsICJhdXRob3IiOiBhdSwgImNvbW1pdHRlciI6IGF1LAogICJtZXNzYWdlIjogImNob3JlOiBhanVzdGVzIGRlIHBsYXRhZm9ybWEgZGUgbGEgc2VtYW5hIiwKICAiZmlsZXMiOiBbeyJvcGVyYXRpb24iOiAidXBkYXRlIiwgInBhdGgiOiAiYXBwcy9hZ2VudGVzL3JiYWMueWFtbCIsICJjb250ZW50IjogYihyYmFjKSwgInNoYSI6IHMxfSwKICAgICAgICAgICAgeyJvcGVyYXRpb24iOiAidXBkYXRlIiwgInBhdGgiOiAibW9uaXRvcmluZy9jb25maWdzL3NlcnZpY2Vtb25pdG9yLXJ1bGV0YS55YW1sIiwgImNvbnRlbnQiOiBiKHNtKSwgInNoYSI6IHMyfSwKICAgICAgICAgICAgeyJvcGVyYXRpb24iOiAidXBkYXRlIiwgInBhdGgiOiAiYXBwcy90aWVuZGEva3VzdG9taXphdGlvbi55YW1sIiwgImNvbnRlbnQiOiBiKGt1KSwgInNoYSI6IHMzfSwKICAgICAgICAgICAgeyJvcGVyYXRpb24iOiAiY3JlYXRlIiwgInBhdGgiOiAiYXBwcy90aWVuZGEvc2VydmljZS55YW1sIiwgImNvbnRlbnQiOiBiKHN2Yyl9XX0pCnByaW50KHJlc1siY29tbWl0Il1bInNoYSJdKQo=' | base64 -d > "$W/.inyeccion.py"
COMMIT=$(python3 "$W/.inyeccion.py" "$API" lab "$GITEA_PASS" "$TOKEN") || { rm -f "$W/.inyeccion.py"; echo "ERROR: no se pudo abrir el incidente ($COMMIT)" >&2; exit 3; }
rm -f "$W/.inyeccion.py"
kubectl -n agentes create configmap incidente --from-literal=hash="$HASH" --from-literal=commit="$COMMIT" --from-literal=reintentos=0 >/dev/null
( umask 077; printf 'TOKEN=%s\nINC=%s\nCOMMIT=%s\nT0=%s\nREINTENTOS=0\n' "$TOKEN" "$ID" "$COMMIT" "$(date +%s)" > "$INC" )

# 4. Dejar que Flux aplique lo que llegó a main y que Prometheus lo note, para que los síntomas del ticket sean reales
g pull -q --rebase origin main
echo "Esperando a que Flux y Prometheus noten los cambios (hasta 5 minutos)..."
CABEZA=$(git -C "$W/fleet" rev-parse HEAD)
for i in $(seq 1 60); do
  LISTO=1
  for k in agentes tienda monitoring-configs; do
    S=$(kubectl -n flux-system get kustomization $k -o jsonpath='{.status.lastAppliedRevision}' 2>/dev/null || true)
    case "$S" in *"$CABEZA"*) ;; *) LISTO=0;; esac
  done
  [ "$LISTO" = 1 ] && break; sleep 3
done
for i in $(seq 1 40); do
  N=$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=count(up%7Bnamespace%3D%22ruleta%22%7D%3D%3D1)" 2>/dev/null | python3 -c 'import json,sys;r=json.load(sys.stdin)["data"]["result"];print(r[0]["value"][1] if r else 0)' 2>/dev/null || echo 2)
  [ "$N" = 0 ] && break; sleep 5
done

cat <<TICKET

============================================================
 TICKET $ID                          prioridad: ALTA
 Abierto: $(date '+%Y-%m-%d %H:%M')    Reporta: guardia de operaciones
============================================================
 Síntomas (lo que se observa, no la causa):
  1. En Grafana, el panel de la ruleta quedó vacío. Prometheus
     ya no muestra objetivos de la ruleta con up==1.
  2. Auditoría de seguridad: la identidad del agente (Paso 7)
     ya no cumple lo que se acordó que podía hacer.
  3. El K8sGPT de la guardia reporta un hallazgo nuevo en el
     namespace tienda.
 Nadie reconoce haber tocado el clúster a mano.
 Su trabajo: Paso 10 del laboratorio (estado requerido y reglas).
 Su ficha secreta quedó en $INC; no la comparta.
============================================================
TICKET

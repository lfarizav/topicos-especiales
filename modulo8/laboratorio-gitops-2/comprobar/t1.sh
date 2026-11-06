. "$(dirname "$0")/_comun.sh"
cd "$W/app" 2>/dev/null || falla "no existe $W/app"
H=$( cd tests && sha256sum *.py | sha256sum | cut -d' ' -f1 )
[ "$H" = "$(cat "$W/.tests.sha")" ] || falla "las pruebas fueron modificadas; arregle el codigo, no las pruebas"
SAL=$("$W/venv/bin/pytest" -q -p no:cacheprovider 2>&1); RC=$?
[ $RC -eq 0 ] || { echo "$SAL" | tail -5; falla "pytest no esta en verde"; }
echo "$SAL" | grep -Eq '^[0-9]+ passed' || falla "no se leyeron pruebas aprobadas"
N=$(echo "$SAL" | grep -Eo '^[0-9]+ passed' | cut -d' ' -f1); [ "$N" -ge 15 ] || falla "se esperaban 15 o mas pruebas, hubo $N"
"$W/venv/bin/python" -c "import ruleta
for n in (1,11):
    try: ruleta.validar([str(i) for i in range(n)])
    except ValueError: continue
    raise SystemExit(1)" || falla "validar() acepta una lista de 1 u 11 valores"
echo ok

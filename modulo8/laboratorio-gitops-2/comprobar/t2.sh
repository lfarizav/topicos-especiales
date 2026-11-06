. "$(dirname "$0")/_comun.sh"
[ -f "$W/llaves/cosign.pub" ] || falla "falta $W/llaves/cosign.pub (genere el par de llaves ahi)"
! find "$W/app" "$W/fleet" -name 'cosign.key' 2>/dev/null | grep -q . || falla "la llave privada esta dentro de un arbol de Git"
D=$(digest ruleta 1.0.0); [ -n "$D" ] || falla "el registro no tiene ruleta:1.0.0"
cosign_ok ruleta "$D" || falla "cosign verify por digest ($D) no sale con 0"
DI=$(digest intruso 1.0.0); [ -n "$DI" ] || falla "falta la imagen intruso en el registro"
! cosign_ok intruso "$DI" || falla "una imagen NUNCA firmada pasa la verificacion: la comprobacion no controla nada"
docker run --rm --entrypoint python "$REG/ruleta@$D" -c "import os;print(os.environ['APP_VERSION'])" 2>/dev/null | grep -qx 1.0.0 || falla "la imagen no se construyo con VERSION=1.0.0"
echo ok

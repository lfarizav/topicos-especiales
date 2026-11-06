#!/bin/bash
# Simula que otro equipo (tienda) publica un cambio con un error. Se aplica desde una carga opaca:
# es una cortesia para que usted diagnostique en vez de leer la respuesta; no es ocultamiento real
# (la clave de respuestas esta al final del laboratorio).
set -euo pipefail
W="$HOME/lab-gitops-2"; export PATH="$W/bin:$PATH"
T=$(mktemp -d)
echo 'H4sIAAAAAAAAA+2YS4/aMBCAOedXWJxLyIMk25wr9dCqhz30UvXgDYa1sOPINqi06n/vmGyoQURoVyG7VefjEPzI2Mk8Hdo0Zj65LRFQFJm7xkUW+deOSZwlRZrmsfsfxUmS5hOS3XhfB7bGUk3IRKyo5j/prm/etfF/FOr0bzmrl/RmZvB8/adZlKD+x8DXf00lMw2tWLinUgy3hlNwni/69V+c6z9P42JCouG20M9/r3/+lWnDVV2SXRxseL0syZfOEALJLF1SS8uAEGceJWltJXjtfSPD4Pv/BnxBSTByC+YwYAy45v9xnpz5f5FGGfr/GPj+3+mfhZWqV3wdbu5MyNV8Fz9AGOiCwyffSgLNjNrqihkXIWbkNIUcupasEWovWW3bvtd+YsTH9/8zTQ22xjX/z/Ki8/+sKBYu/+fRAv1/DHz/P9jCsQj4cLSGC1VABS2h1uqp4+Dyx9qAEEEfmDAl+QUi/07+HZiGVU6IBtm8ojAjhpZhglVWaTdCiKS2evzcI4AQy2QjqGVPk72dOfoWdmPd4g4IcJbyGp686+mi18mzdXBJ1zCy5lY1JplptubG6n2ZgfXOu/nl+xB+3l2VkpK6V/ltagRjzfQdmaZ5FE2/v50gWAlwAHgNt/wG8ILzX5wWeP4bg6P+ZXR3Kxt4yfl/kaL+x+BE/238Hvj0fz3/p4v8TP9QEeSY/8fgcv1vlRIbbsOV2P6olu0Z4GL53/t94KQucGJmZg+GJo8lAK/B7HZUlCSNDLQbva3d7XrLXElwOFTcs1WbntulP3J7zxplIAvr/aG/XdIXD4KofSxJOPcq27eTbhEEQRAEQRAEQRAEQUbnD+qHpKsAKAAA' | base64 -d | tar -xzf - -C "$T"
cp -r "$T/apps/tienda" "$W/fleet/apps/"
cp "$T/clusters/m08/tienda.yaml" "$W/fleet/clusters/m08/"
rm -rf "$T"
g add -A
g -c user.name="Equipo tienda" -c user.email="tienda@example.com" commit -qm "feat(tienda): desplegar catalogo"
g push -q origin main
echo "Cambio de tienda publicado en main."

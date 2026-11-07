# Fuente del mapa del curso

Esta carpeta genera las dos figuras del README principal:

- `../mapa-del-curso-claro.svg` (tema claro)
- `../mapa-del-curso-oscuro.svg` (tema oscuro)

Son SVG estáticos: estilos incrustados, sin JavaScript y sin animación. GitHub los
muestra como imagen tal cual.

## Qué muestra la figura

Una torre isométrica de terrazas. Cada capa es un módulo del curso y el proyecto del
estudiante sube por escaleras de una capa a la siguiente.

| Pieza del dibujo | Módulo |
|---|---|
| Losa base con patas, terminal y regla | Módulo 1 · Linux (LFCS) |
| Escritorio con dos documentos (PVB y PRD) y una bombilla | Módulo 2 · IA y especificaciones |
| Segunda terraza con contenedores | Módulo 3 · Contenedores |
| Terraza superior (el clúster) | Módulo 4 · Kubernetes (KCNA) |
| Nodo del plano de control con discos de etcd | Módulo 5 · CKA |
| Nodos trabajadores con pods | Módulo 6 · CKAD |
| Valla con puerta alrededor del clúster | Módulo 7 · CKS |
| Repositorio Git, cinta con commits y receptor | Módulo 8 · GitOps, CI/CD e IaC |
| Agente sobre el clúster | Módulo 8 · Agentes de IA |
| Caja con timón, línea discontinua | Módulo 9 · Helm (opcional) |

El camino punteado con banderas es el proyecto: Idea, PVB, PRD, Unidades y tareas,
Producción. Es la única pieza resaltada (blanco en oscuro, negro en claro).

## Cómo reconstruir

Requisitos: Node.js 18 o superior. Para las vistas previas, Google Chrome.

```bash
cd assets/fuente-mapa
node build.mjs          # escribe los dos SVG en ../
./render.sh 1 1000 720  # opcional: PNG de revisión en previews/
```

## Variantes "Estás aquí" por módulo

Cada `moduloN/README.md` muestra el mismo mapa con su módulo resaltado:
`../modulos/mapa-modulo-N-{claro,oscuro}.svg`, N de 1 a 9. Se generan con el parámetro
`--modulo N`: las piezas y etiquetas del módulo N quedan a plena intensidad con un
único acento azul (`#2f6fe8`, igual en claro y oscuro) y todo lo demás se atenúa por
opacidad. El título pasa a "Estás aquí: Módulo N · nombre corto" y el subtítulo se
conserva. El Módulo 8 resalta a la vez GitOps y CI/CD, IaC y Agentes de IA. Sin
`--modulo` el mapa principal sale idéntico byte a byte.

```bash
cd assets/fuente-mapa
node build.mjs --modulo 8                 # una variante (unos 40 s por módulo)
for n in 1 2 3 4 5 6 7 8 9; do node build.mjs --modulo $n; done   # las nueve
MODULO=8 ./render.sh 1 900 648            # PNG de revisión en previews/modulo-8-*.png
```

La asociación pieza a módulo está en la lista `art` de `build.mjs` (función `grp`) y
en el parámetro `mods` de cada `label(...)`.

`node build.mjs --html` escribe además `vista-claro.html` y `vista-oscuro.html`,
envoltorios para revisar el dibujo en el navegador. No hace falta conservarlos.

## Archivos

- `build.mjs`: toda la geometría, las etiquetas y la composición.
- `iso-kit.mjs`: núcleo de dibujo isométrico (cámara, sólidos, líneas), copiado del
  kit de la skill `anatomy`. Licencia MIT, ver `LICENSE-iso-kit`.
- `render.sh`: renderiza los SVG a PNG con Chrome sin interfaz (con `MODULO=N`, una variante).
- `previews/`: PNG de revisión (mapa principal y dos muestras de variantes, módulos 2 y 8).

## Para cambiar textos

Las etiquetas de los módulos están en las llamadas `label(...)` al final de
`build.mjs`; los hitos del proyecto, en `milestones`. La posición vertical de cada
etiqueta se calcula sola a partir del punto que señala. No uses la raya larga
(em-dash) en ningún texto.

_Creado con ❤️ por Luis Felipe Ariza Vesga._

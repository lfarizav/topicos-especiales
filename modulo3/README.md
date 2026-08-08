# Módulo 3 — Docker, Compose y Runtimes de Contenedores

**Sesión 3 · sábado 15 de agosto de 2026 · 9:00–12:00**

Doble propósito. En lo técnico, este módulo baja el contenedor de la metáfora al
mecanismo: namespaces, cgroups y union filesystem. En lo de producto, aquí conviertes
el Product Vision Board del módulo 2 en un **PRD** (Product Requirements Document).

---

## Objetivos de aprendizaje

- Distinguir contenedor de máquina virtual: namespaces, cgroups, union filesystem.
- Escribir un `Dockerfile` multi-stage que minimice tamaño y superficie de ataque.
- Redactar un `compose.yaml` de nivel producción con las 6 prácticas no negociables.
- Operar el CLI de Docker con fluidez: ciclo de vida, imágenes, redes, volúmenes.
- Diagnosticar un stack de Compose que no arranca: logs, `inspect`, healthchecks.
- Distinguir el estado real del runtime en el nodo del que reporta `kubectl get nodes`.

---

## Agenda

| Tema | Contenido |
|---|---|
| Fundamentos | Qué es realmente un contenedor: namespaces, cgroups, union FS |
| Construir imágenes | `Dockerfile`, multi-stage, imágenes distroless, arquitectura interna |
| Compose en producción | Las 6 prácticas no negociables |
| Operación diaria | CLI de Docker, cgroups, diagnóstico |
| Puente al CKA | Visibilidad del runtime, permisos de Docker |

### Las 6 prácticas no negociables de Compose

1. Secretos por archivo, nunca en variables de entorno en claro
2. Arranque condicionado a healthcheck (`depends_on: condition: service_healthy`)
3. Redes con nombre explícito
4. Volúmenes con nombre explícito
5. `cap_drop: [ALL]` y capacidades añadidas una por una
6. `security_opt: no-new-privileges:true`

---

## Laboratorio

**Dockerfile multi-stage y Compose de producción** — 60 minutos, 7 pasos:

1. Build multi-stage de una app Go hacia una imagen `distroless`
2. `compose.yaml` sin clave `version:`, validado con `docker compose config`
3. Secretos por archivo (`POSTGRES_PASSWORD_FILE`)
4. `depends_on` con `condition: service_healthy`
5. Red y volumen con nombre explícito
6. Hardening: `cap_drop: [ALL]`, `no-new-privileges:true`
7. Comprobar que pertenecer al grupo `docker` equivale a ser root en el host

**Herramientas:** Docker Engine y CLI, Docker Compose v2, Podman, Trivy,
`containerd`, imágenes distroless.

---

## Entregable de producto: el PRD

Traes tu `pvb.md` del módulo 2 completado. En este módulo lo conviertes en un PRD.

**La patología conocida del PRD:** cada sesión con el agente abre direcciones nuevas
y el alcance crece sin que nadie haya decidido que creciera. La salida no es más
disciplina personal — es volver al tablero y hacer **una sola pregunta de corte**:

> ¿esto sigue siendo el producto que quiero construir?

La técnica concreta: dale al agente el PVB y el PRD **juntos** y pídele que señale
conflictos y desalineaciones, **no que decida por ti**. El PRD está terminado cuando
no le falta ni le sobra nada respecto de la visión.

### Material de referencia en esta carpeta

Los archivos de investigación y análisis de un caso de estudio completo, para que veas
el nivel de profundidad esperado antes de escribir el tuyo:

| Archivo | Qué es |
|---|---|
| `overview.md` | Panorama del dominio, con fuentes |
| `pvb.md` | Product Vision Board completo del caso |
| `icp.md` | Perfil de cliente ideal y buyer personas |
| `mercado.md` | Análisis de mercado y marco regulatorio |
| `critica.md` | Investigación adversarial: por qué la idea podría fracasar |

Lee `critica.md` con especial atención. Es el documento que separa un PVB de tarea de
un PVB defendible.

---

## Cómo conecta con el resto del curso

- **Módulo 4 en adelante:** Kubernetes no construye imágenes; orquesta las que aquí
  aprendes a construir.
- **Módulo 5 (CKA):** el dominio de troubleshooting pesa 30%, y el runtime del nodo
  es el primer lugar donde se mira.
- **Módulo 7 (CKS):** la cadena de suministro de software pesa 20%, y empieza en el
  `Dockerfile`.

# Módulo 8: A Producción: Paisaje CNCF, Agentes y GitOps

**Sesiones 13 y 14 · sábados 31 de octubre y 7 de noviembre de 2026 · 9:00–12:00**

El módulo donde todo cierra. El producto que fijaste en el módulo 2, especificaste en
el 3 y aprendiste a construir en los módulos 4 a 7, aquí llega a producción, y se
queda ahí, operado con ayuda de agentes de IA.

Es también el módulo que da forma a la **sustentación final** de la sesión 16.

---

## Objetivos de aprendizaje

- Seleccionar herramientas del paisaje CNCF (Argo CD/Flux, Helm, Trivy, Cosign,
  Cilium, Crossplane, Prometheus/OpenTelemetry) y describir cómo un agente las conecta.
- Operar agentes dentro del clúster (**kagent**, **K8sGPT**, **HolmesGPT**) y explicar
  qué hace cada uno **y cuáles son sus puntos ciegos**.
- Acotar un agente con dos capas independientes: **allowlist de herramientas** y
  **RBAC del ServiceAccount**.
- Cerrar el bucle GitOps: detectar → diagnosticar → **proponer un PR con evidencia** →
  aprobar → reconciliar. Nunca auto-aprobar.

---

## Agenda

| Tema | Contenido |
|---|---|
| El ciclo de vida envuelto en IA | El paisaje CNCF y dónde encaja cada pieza |
| Los tres agentes del clúster | kagent, K8sGPT, HolmesGPT: qué hace cada uno |
| Allowlist y RBAC | Las dos capas del sandbox del agente |
| El bucle GitOps | Detectar, diagnosticar, proponer un pull request |
| Reto | Construir el agente auditor que termina en un pull request |

---

## La regla que gobierna todo el módulo

> **El agente propone, un humano aprueba.**

No es filosofía, es diseño. Cada capa que verás aquí (el allowlist de herramientas MCP,
el RBAC del ServiceAccount del agente, el gate de CI, la revisión del pull request)
existe para que el robot pueda hacer el trabajo **sin poder darse su propio visto bueno**.

El destino de la cadena del agente no es un `kubectl apply` autónomo: es **un pull
request con la evidencia adjunta**. Esa diferencia es la que hace que un SRE te deje
conectar un agente a su producción.

---

## Laboratorios

### Laboratorio 1

**[Laboratorio 1: GitOps desde cero, de Git al clúster, de la firma a la infraestructura](./laboratorio-gitops-1.md)**
(sesión 13, 120–140 min). Se ejecutó de principio a fin en un clúster `kind` limpio (Kubernetes
v1.36.1) con Flux 2.10.0, `kubeconform` 0.8.0, `cosign` 3.1.3 y OpenTofu 1.12.6; las salidas no
están escritas a mano. Requiere Docker, `kind`, `kubectl` y `git`. El montaje y el desmontaje
viven en `laboratorio-gitops-1/`.

1. Clúster `kind`, Gitea y registro locales, con las herramientas descargadas y su suma SHA-256 verificada
2. Flux se instala a sí mismo desde un repositorio Git (modelo de extracción)
3. Un cambio declarativo: la aplicación entra por Git y `managedFields` prueba quién la escribió
4. Deriva y reconciliación: con 5 minutos la edición a mano sobrevive, con 30 segundos Flux la deshace
5. Reversa con `git revert`: un cambio malo en Git y el rollback como un commit nuevo
6. Compuerta de CI en miniatura con `kustomize` y `kubeconform`, y por qué `--no-verify` la salta
7. Firmar y verificar una imagen por digest con `cosign`, y la etiqueta que se mueve
8. OpenTofu: `plan`, `apply` y deriva con `tofu plan -detailed-exitcode`
9. Reto estilo examen de 7 chequeos, calificado por `verificador-reto1.sh`

### Laboratorio 2

**[Laboratorio 2: la ruleta de extremo a extremo](./laboratorio-gitops-2.md)** (sesión 14). La
ruleta de extremo a extremo con CI, firma, automatización de imágenes de Flux, observabilidad y
reversa, y la IA sobre los cimientos con K8sGPT y un agente que propone cambios. Construye sobre lo
que dejó el laboratorio 1: el agente tiene un destino fijo, un pull request con evidencia, nunca un
`kubectl apply`.

**Herramientas:** kagent, K8sGPT, HolmesGPT, Flux v2 (source-controller,
kustomize-controller, helm-controller, notification-controller), Argo CD, SOPS + Age,
Helm, Crossplane, Trivy, Cosign, Cilium, Prometheus, OpenTelemetry, Grafana, Kyverno.

---

## Proyecto final

La sustentación de la **sesión 16 (sábado 21 de noviembre de 2026)** presenta el arco
completo:

1. El **PVB** del módulo 2 y qué cambió desde entonces (si nada cambió, no investigaste)
2. El **PRD** del módulo 3 y las decisiones de alcance que tomaste
3. La aplicación **corriendo en Kubernetes**
4. El **bucle GitOps** funcionando: un cambio en Git que se reconcilia en el clúster
5. Un **agente** operando dentro de sus límites, con la evidencia de que no puede
   salirse de ellos (`kubectl auth can-i` es tu mejor diapositiva)
6. Los **riesgos** que documentaste y cómo los mitigaste

Se evalúa el arco completo y la honestidad del análisis, no solo que la demo funcione.

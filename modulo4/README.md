# Módulo 4 — Kubernetes Fundamentals (KCNA)

**Sesión 4 · sábado 22 de agosto de 2026 · 9:00–12:00**

El primer contacto serio con Kubernetes. La idea central del módulo cabe en una frase:
Kubernetes no ejecuta tu aplicación, **reconcilia** un estado deseado con el estado
real, una y otra vez, para siempre. Todo lo demás es consecuencia de eso.

Certificación de referencia: **KCNA** (Kubernetes and Cloud Native Associate).

---

## Objetivos de aprendizaje

- Comprender el loop **Watch-Diff-Update** de los controladores: el corazón del sistema.
- Entender EndpointSlices y cómo un Service llega realmente a sus pods.
- Entender los Admission Webhooks: dónde se intercepta y modifica lo que entra al clúster.
- Configurar Multi-Service CIDRs sin recrear el clúster.
- Habilitar Node Memory Swap (Kubernetes 1.29+) y entender cgroup v2.

---

## Agenda

| Tema | Contenido |
|---|---|
| Fundamentos de Kubernetes | Arquitectura, API declarativa, el loop de reconciliación |
| Orquestación de contenedores | Pods, Deployments, Services, scheduling |
| Entrega de aplicaciones cloud native | Helm, Kustomize, introducción a GitOps |
| Arquitectura cloud native | El ecosistema CNCF, CNI, runtimes |

---

## Laboratorio

[**Kubernetes: reconciliación, EndpointSlices y Admission**](./laboratorio-kubernetes.md),
en clase, 105–120 minutos, 7 pasos. Se hace sobre un clúster `kind` de un solo nodo que
tú creas y borras en la misma sesión:

| Paso | Contenido | Tiempo |
|---|---|---|
| 0 | Verificar herramientas y crear el clúster (imagen fijada por digest, swap del kubelet) | ~10 min |
| 1 | La arquitectura de verdad: static pods, kubelet bajo systemd, `containerd` vía `crictl` | ~15 min |
| 2 | Deployment + Service → EndpointSlice, reglas de `kube-proxy`, CoreDNS | ~20 min |
| 3 | Watch-Diff-Update: borrar un pod y ver al ReplicaSet reconciliar | ~15 min |
| 4 | Admission: `LimitRanger` y tu propio `MutatingWebhookConfiguration` | ~30 min |
| 5 | cgroup v2 y Node Memory Swap: `configz`, QoS y `memory.swap.max` | ~15 min |
| 6 | Escalar réplicas y ver los EndpointSlices actualizarse en vivo | ~10 min |

Si la clase va corta de tiempo, recorta desde el final (6, luego 5). Los pasos 0–3 son el
núcleo y no se pueden saltar.

**Requisitos:** Linux con Docker Engine activo, `kind` v0.32.0+, `kubectl` v1.36.x
(soportado dentro de un *minor* del API server) y `openssl`. Swap activo en el host es
opcional: el laboratorio dice qué cambia si no lo tienes.

**Herramientas y conceptos:** `kubectl`, `kind`, `crictl`, EndpointSlices, Admission
Webhooks, `LimitRange`, cgroup v2, Node Memory Swap, CNI (aquí `kindnet`; en producción
Cilium, Calico, Flannel), `containerd` / CRI. Helm y Kustomize se mencionan en la sesión,
pero este laboratorio no los usa.

---

## Dominios del examen KCNA

El examen cubre fundamentos de Kubernetes, orquestación de contenedores, entrega de
aplicaciones cloud native, arquitectura cloud native y observabilidad.

> **Consulta los pesos oficiales vigentes en la página del examen KCNA de la CNCF.**
> El currículo se revisa periódicamente y los pesos cambian entre versiones; no
> estudies con una tabla de pesos copiada de un blog.

---

## Cómo conecta con el resto del curso

- **Módulo 5 (CKA):** aquí ves el loop de reconciliación; allá lo depuras cuando falla.
- **Módulo 8:** el bucle GitOps es exactamente este loop de reconciliación, extendido
  hasta el repositorio Git.

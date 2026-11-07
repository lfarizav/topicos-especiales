# Tópicos Especiales en Informática

> Ingeniería cloud-native, frameworks agénticos y desarrollo dirigido por especificaciones.

**Maestría en Ingeniería de Sistemas · Pontificia Universidad Javeriana · Bogotá**
**Semestre 2026-3 · Sábados 9:00–12:00**

De la máquina Linux al clúster en producción operado con ayuda de agentes de IA, en
un solo arco continuo. No son ocho temas sueltos: son ocho etapas del mismo camino.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/mapa-del-curso-oscuro.svg">
    <img src="assets/mapa-del-curso-claro.svg" alt="Mapa del curso: de Linux a producción con GitOps y agentes de IA" width="900">
  </picture>
</p>

---

## Módulos

Empieza siempre por el `README.md` de cada módulo: trae objetivos, contenido,
laboratorios y entregables.

| # | Módulo | Certificación y enfoque | Laboratorios |
|---|---|---|---|
| 1 | [Fundamentos de Linux](./modulo1/) | LFCS: el suelo sobre el que corre todo | Hardening de host, almacenamiento y red |
| 2 | [AI & Agentic Engineering](./modulo2/) | Enfoque: la idea, fijada en un Product Vision Board | - |
| 3 | [Docker, Compose y Runtimes de Contenedores](./modulo3/) | Enfoque: la unidad de despliegue + el PRD | [Virtualización y contenedores](./modulo3/laboratorio-virtualizacion-contenedores.md) y Compose de producción |
| 4 | [Kubernetes Fundamentals](./modulo4/) | KCNA: el loop de reconciliación | [Primeras cargas de trabajo](./modulo4/laboratorio-kubernetes.md) |
| 5 | [Certified Kubernetes Administrator](./modulo5/) | CKA: administrar el clúster + las unidades y tareas (AI-DLC) | [CKA 1](./modulo5/laboratorio-cka-1.md) · [CKA 2](./modulo5/laboratorio-cka-2.md) |
| 6 | [Certified Kubernetes Application Developer](./modulo6/) | CKAD: desplegar aplicaciones en el clúster | [CKAD 1](./modulo6/laboratorio-ckad-1.md) · [CKAD 2](./modulo6/laboratorio-ckad-2.md) |
| 7 | [Certified Kubernetes Security Specialist](./modulo7/) | CKS: asegurar el clúster | [CKS 1](./modulo7/laboratorio-cks-1.md) · [CKS 2](./modulo7/laboratorio-cks-2.md) |
| 8 | [A Producción: GitOps, CI/CD, IaC y Agentes de IA](./modulo8/) | Enfoque: GitOps, CI/CD, IaC y agentes de IA | [GitOps 1](./modulo8/laboratorio-gitops-1.md) · [GitOps 2](./modulo8/laboratorio-gitops-2.md) |
| 9 | [Helm: el gestor de paquetes de Kubernetes (opcional)](./modulo9/) | Enfoque: empaquetar y versionar manifiestos | [Helm](./modulo9/laboratorio-helm.md) |

> El módulo 9 es opcional: no tiene fecha en el cronograma de abajo, no reemplaza ninguna
> sesión y no forma parte del proyecto final evaluado. Profundiza en Helm, herramienta que
> el módulo 8 solo menciona dentro del paisaje CNCF.

---

## Cronograma: 16 sesiones

| # | Fecha | Sesión | Entregable |
|---|---|---|---|
| 1 | sáb 1 ago 2026 | Módulo 1: Fundamentos de Linux | - |
| 2 | sáb 8 ago 2026 | Módulo 2: AI & Agentic Engineering | - |
| 3 | sáb 15 ago 2026 | Módulo 3: Docker, Compose y Runtimes | **PVB + PRD** |
| 4 | sáb 22 ago 2026 | Módulo 4: Kubernetes Fundamentals (KCNA) | - |
| 5 | sáb 29 ago 2026 | **Examen 1**: módulos 1 a 4 | - |
| 6 | sáb 5 sep 2026 | Módulo 5: CKA (1/2) | - |
| 7 | sáb 12 sep 2026 | Módulo 5: CKA (2/2) | - |
| - | **14 – 19 sep 2026** | **Semana de descanso (no hay clase)** | - |
| 8 | sáb 26 sep 2026 | Módulo 6: CKAD (1/2) | - |
| 9 | sáb 3 oct 2026 | Módulo 6: CKAD (2/2) | - |
| 10 | sáb 10 oct 2026 | **Examen 2**: módulos 5 y 6 | - |
| 11 | sáb 17 oct 2026 | Módulo 7: CKS (1/2) | - |
| 12 | sáb 24 oct 2026 | Módulo 7: CKS (2/2) | - |
| 13 | sáb 31 oct 2026 | Módulo 8: GitOps, CI/CD, IaC y Agentes de IA (1/2) | - |
| 14 | sáb 7 nov 2026 | Módulo 8: GitOps, CI/CD, IaC y Agentes de IA (2/2) | - |
| 15 | sáb 14 nov 2026 | **Examen 3**: módulos 7 y 8 | - |
| 16 | sáb 21 nov 2026 | **Sustentación del proyecto final** | **Proyecto final** |

Este cronograma es la fuente de verdad del curso. Si una fecha cambia, se cambia aquí
primero.

---

## El hilo del proyecto

Recorres el arco completo con **un producto tuyo**:

1. **Módulo 2:** eliges una idea que corra sobre Kubernetes y use IA de forma defendible.
2. **Módulo 3:** la conviertes en requisitos.
3. **Módulos 4 a 7:** adquieres la capacidad técnica para construirla.
4. **Módulo 8:** la llevas a producción.
5. **Sesión 16:** la sustentas.

> **Tercer entregable del proyecto: unidades y tareas.** El módulo 5 lleva, además de los
> dos laboratorios de CKA, el paso que convierte tu PVB y tu PRD en **unidades de trabajo
> con sus tareas**, con el marco AI-DLC de AWS. La guía está en
> [`modulo5/proyecto-final-de-prd-a-unidades-y-tareas.md`](./modulo5/proyecto-final-de-prd-a-unidades-y-tareas.md).
> La fecha y el mecanismo de entrega se anuncian en clase.

---

## Cómo se trabaja en este curso

**Toda afirmación lleva fuente.** Una cifra de mercado sin enlace es una cifra
inventada. Esto aplica a tu PVB, a tu PRD y a tu sustentación.

**La investigación crítica pesa tanto como la de validación.** Se te va a pedir que
ataques tu propia idea y encuentres por qué fallaría. Un análisis sin riesgos reales
es un análisis que no se hizo.

**El agente propone, el humano aprueba.** Usas IA intensamente en todo el curso, pero
nunca le entregas la decisión ni la aprobación. Esa frontera es materia evaluable.

---

## Estructura del repositorio

Cada carpeta de módulo tiene su `README.md` con objetivos, agenda, laboratorio y
entregables. Empieza siempre por ahí.

`research/` contiene paquetes de investigación profunda listos para ejecutar.

_Creado con ❤️ por Luis Felipe Ariza Vesga._

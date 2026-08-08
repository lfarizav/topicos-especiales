# Módulo 2 — AI & Agentic Engineering

**Sesión 2 · sábado 8 de agosto de 2026 · 9:00–12:00**

Este módulo arranca el hilo que atraviesa todo el semestre. A partir de hoy no
estudias Kubernetes en abstracto: eliges **un producto** y lo construyes módulo a
módulo hasta llevarlo a producción en la sesión 14.

---

## El arco completo del curso

```
Módulo 2  →  idea validada       →  Product Vision Board  (pvb.md)
Módulo 3  →  requisitos          →  PRD                   (prd.md)
Módulos 3-7 →  capacidad técnica →  contenedores, K8s, CKA, CKAD, CKS
Módulo 8  →  producción          →  GitOps, agentes en el clúster, observabilidad
Sesión 16 →  sustentación        →  proyecto final
```

Tu entregable final no es solo el software: es **la fábrica que lo produce** y la
evidencia verificable en cada paso.

---

## Qué hay en esta carpeta

| Archivo | Qué es |
|---|---|
| `README.md` | Esta guía. Léela primero. |
| `pvb.md` | Plantilla del **Product Vision Board** + reglas de llenado + un ejemplo completo de referencia al final |

---

## Tu tarea para la sesión 3 (sábado 15 de agosto de 2026)

Llegas con tu `pvb.md` completado y tu investigación documentada.

### 1. Elige tu producto

Una idea propia que cumpla **dos condiciones no negociables**:

- **Corre sobre Kubernetes.** No "podría desplegarse en Kubernetes algún día":
  la arquitectura tiene sentido en un clúster.
- **Usa IA de forma defendible.** IA dentro del producto, o agentes operándolo.
  Si al quitar la IA el producto sigue funcionando igual, no cuenta.

Si tu idea no pasa esas dos condiciones, no vas a poder construirla en los módulos
siguientes ni sustentarla en la sesión 16.

### 2. Investiga con IA — dos investigaciones, no una

**Deep research de validación.** ¿El problema existe de verdad? ¿Quién más lo ha
resuelto y cómo? ¿Qué herramientas del ecosistema CNCF ya cubren parte de esto?

**Deep research de crítica (adversarial).** Esta es la que importa y la que casi
nadie hace. Pídele explícitamente a la IA que **ataque tu idea**: por qué fallaría,
quién ya la está comoditizando gratis, qué riesgo técnico la mata. Estúdiala tan en
serio como la de validación.

> **Regla de evidencia:** toda cifra que escribas lleva fuente. Si tu investigación
> dice "el mercado es de $X mil millones", quiero el enlace y la fecha. Una cifra
> sin fuente es una cifra inventada, y en la sustentación se cae sola.

### 3. Documenta todo en Markdown

Transcripciones de entrevistas, notas, análisis, capturas de la investigación.
Este material lo vas a reusar para co-crear tu PRD en el módulo 3.

### 4. Completa `pvb.md`

Llena cada sección con base en tu investigación, no en tu intuición.

---

## Reglas de llenado

- **Sé específico.** "Empresas" no es un segmento. "Equipos de plataforma de 3 a 15
  ingenieros que ya operan Kubernetes en producción" sí lo es.
- **No escribas "queremos usar IA para X".** Escribe el dolor concreto que resuelves.
- **Si no puedes responder una sección con confianza, no la rellenes con humo** —
  esa es exactamente la señal de que te falta investigación.
- Trae tus dudas a clase.

---

## Checklist antes de la sesión 3

- [ ] Producto seleccionado, corre sobre Kubernetes y usa IA de forma defendible
- [ ] Deep research de **validación** completado y estudiado
- [ ] Deep research de **crítica** completado y estudiado
- [ ] Investigación documentada en archivos Markdown, con fuentes
- [ ] `pvb.md` completado
- [ ] Ejemplo de referencia (final de `pvb.md`) leído — ese es el nivel esperado

---

## Cómo se evalúa este entregable

| Criterio | Qué busco |
|---|---|
| Especificidad | Segmento, dolor y métricas concretas, no genéricas |
| Evidencia | Afirmaciones con fuente verificable |
| Honestidad crítica | Que hayas encontrado y aceptado las debilidades reales de tu idea |
| Coherencia técnica | Que Kubernetes e IA sean centrales, no decorativos |
| Viabilidad | Que sea construible en lo que queda del semestre |

La sección más valiosa de tu PVB es la de **riesgos críticos**. Un PVB sin riesgos
reales es un PVB que no se investigó.

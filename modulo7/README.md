# Módulo 7: Certified Kubernetes Security Specialist (CKS)

**Sesiones 11 y 12 · sábados 17 y 24 de octubre de 2026 · 9:00–12:00**

El módulo más exigente del curso. Requiere tener CKA vigente para presentar el examen,
y con razón: no se puede asegurar lo que no se sabe administrar.

Premisa del módulo: **un clúster de Kubernetes por defecto no es seguro**. Es
permisivo por diseño, para que funcione. Endurecerlo es trabajo explícito.

Certificación de referencia: **CKS**.

---

## Objetivos de aprendizaje

- Defensa activa en tiempo real con **Tetragon** (enforcement con eBPF).
- Cifrado pod-a-pod con **Cilium + WireGuard**, sin gestionar certificados a mano.
- Políticas como código con **Kyverno**: validación y mutación.
- Hardening de nodos con **CIS Kubernetes Benchmark** y `kube-bench`.
- Auditoría del API server y envío de logs a un SIEM para análisis forense.
- NetworkPolicies default-deny **sin romper el DNS del clúster**.
- Pod Security Standards vía Pod Security Admission y cifrado de Secrets en reposo.
- Detección de comportamiento anómalo en runtime con reglas de **Falco**.

---

## Dominios del examen CKS

| Dominio | Peso |
|---|---|
| Minimización de vulnerabilidades en microservicios | 20% |
| Seguridad de la cadena de suministro | 20% |
| Supervisión, registro y seguridad en runtime | 20% |
| Configuración del clúster | 15% |
| Fortalecimiento del clúster | 15% |
| Fortalecimiento del sistema | 10% |

> Verifica los pesos vigentes en la página oficial del examen CKS de la CNCF antes de
> presentarlo.

---

## Laboratorio 1

**[Laboratorio 1: endurecer un clúster y las cargas que corren en él](./laboratorio-cks-1.md)**
(sesión 11, 130–150 min). Sus salidas se capturaron ejecutando los comandos en clústeres `kind`
limpios (kind v0.33, Kubernetes v1.37); no están escritas a mano.

1. Clúster `kind` con la Audit Policy ya montada, alias `k`, `--dry-run=client` y `kubectl explain`
2. CIS Benchmark con `kube-bench` v0.16.0: de 9 `FAIL` a 3, y por qué las otras 3 no se arreglan en `kind`
3. NetworkPolicy `default-deny` que rompe el DNS a propósito, `permitir-dns` y el tráfico decidido por etiqueta
4. Pod Security Admission `restricted`: el rechazo completo y el Pod mínimo que cumple
5. Kyverno por Helm: una `ClusterPolicy` con dos reglas, `Enforce` frente a `Audit`
6. Audit Policy: el `create` de un Secret con código 201 en `audit.log`
7. Cifrado de Secrets en reposo con `aescbc`, leído con `etcdctl` antes y después
8. Reto estilo examen de 10 chequeos, calificado por `verifier-reto1.sh`

---

## Laboratorio 2

**[Laboratorio 2: defensa en runtime y cadena de suministro](./laboratorio-cks-2.md)**
(sesión 12, 130–150 min). Sus salidas se capturaron ejecutando los comandos en un clúster `kind`
nuevo llamado `cks2` (kind v0.33, Kubernetes v1.37); no están escritas a mano. Los fallos que
aparecen (una política que se acepta pero no carga, banderas de cosign v3, una API distinta a la
esperada) ocurrieron de verdad y se dejan como material de aprendizaje.

0. Clúster `kind` limpio, registro local `registry:2` y el hábito de comprobar el contexto de `kubectl`
1. Falco 0.45.1 como DaemonSet con la sonda `modern_ebpf` (sin Driver Loader en este chart)
2. Disparar reglas: `cat /etc/shadow`, `nc -e`, un hueco real de las reglas por defecto y una regla propia
3. Tetragon v1.7.1: `TracingPolicyNamespaced` con `Sigkill`, el estado `load_error` y la carrera con Pods de vida corta
4. Firmar con cosign (par de claves local, sin Fulcio ni Rekor) y verificar
5. Kyverno v1.18.2: `ImageValidatingPolicy` (en `policies.kyverno.io/v1`, no en `v2alpha1`) y por qué necesita una firma en formato `.sig`
6. Trivy 0.74.0: `--exit-code 1`, SBOM CycloneDX y re-escaneo del SBOM
7. Reto estilo examen de 11 chequeos, calificado por `verificar-reto2.sh`

**Lo que no se pudo demostrar:** la sonda `security_kernel_module_request` de Tetragon carga pero
no se logró dispararla desde un Pod sin privilegios; el laboratorio lo dice explícitamente.

---

## Laboratorio

**Tetragon, Kyverno y CIS Benchmark** (60 minutos, 5 pasos, requiere Tetragon y
Kyverno instalados vía Helm):

1. `TracingPolicy` de Tetragon que bloquea `security_kernel_module_request` con acción
   `Sigkill`: enforcement real con eBPF, no solo alerta
2. `ClusterPolicy` de Kyverno que rechaza pods privilegiados
   (`validationFailureAction: Enforce`)
3. Pod Security Standards por etiquetas de namespace: `enforce`, `warn`, `audit`
4. Audit Policy del API server: niveles `RequestResponse`, `Request`, `Metadata`, `None`
5. Ejecutar `kube-bench` como pod privilegiado montando `/var/lib/kubelet`

**Herramientas:** Falco, Tetragon, Kyverno, OPA/Gatekeeper, Cosign, Trivy,
`kube-bench`, CIS Kubernetes Benchmark, AppArmor, Cilium + WireGuard.

---

## Falco y Tetragon no son lo mismo

| | Falco | Tetragon |
|---|---|---|
| Qué hace | **Detecta** y alerta | Detecta y **bloquea** (`Sigkill`) |
| Momento | Después del hecho | En el momento de la llamada al kernel |
| Riesgo | Te enteras tarde | Una política mal escrita mata procesos legítimos |

Se usan juntos: Falco para cobertura amplia de detección, Tetragon para enforcement
quirúrgico en lo que de verdad no puede pasar.

---

## Cómo conecta con el resto del curso

- **Módulo 1:** el fortalecimiento del sistema operativo del nodo empieza en Linux.
- **Módulo 3:** la cadena de suministro empieza en el `Dockerfile` y la imagen base.
- **Módulo 8:** el RBAC restrictivo del agente de IA en el clúster es una aplicación
  directa de este módulo. Un agente con permisos de escritura es un hallazgo de CKS.

# Laboratorio — Runtimes de contenedores y virtualización ligera

**Módulo 3 · en clase · 75–90 minutos** (Pasos 0–5: núcleo, ~50 min. Pasos 6–7: red,
almacenamiento, vulnerabilidades y privilegios, ~25–30 min más. Si la clase va corta de
tiempo, los Pasos 6 y 7 son los primeros que se pueden dejar como lectura/práctica en
casa sin romper la progresión — el resto sí depende uno del otro en orden.)

> Este laboratorio es distinto del laboratorio de `README.md` (Dockerfile multi-stage +
> Compose de producción, para la entrega de PVB/PRD). Este se hace **en vivo, en clase**,
> antes o junto con ese trabajo: el objetivo aquí no es producir un artefacto, es que
> las cuatro palabras que más se confunden en contenedores — **OCI, LXC, LXD, Docker** —
> dejen de ser sinónimos vagos y se conviertan en cosas que viste con tus propios ojos
> en una terminal.

---

## Objetivo

Al terminar, vas a poder responder estas cuatro preguntas señalando la evidencia en tu
propia terminal, no repitiendo una definición de memoria:

1. ¿Qué es, concretamente, lo que hace que un proceso normal de Linux se convierta en
   "un contenedor"? (namespaces + cgroups — el módulo 1 lo vio en teoría, aquí lo ves
   correr)
2. ¿Por qué un **contenedor de sistema** (LXC/LXD) y un **contenedor de aplicación**
   (Docker) son dos formas distintas de usar el mismo mecanismo del kernel, no dos
   mecanismos distintos?
3. ¿Qué es LXD que Docker no es, y qué es Docker que LXD no es — usando la misma
   herramienta (`lxc`) para lanzar tanto un contenedor como una máquina virtual ligera?
4. ¿Qué significa "imagen oficial" en Docker Hub, y por qué el tamaño de una imagen es
   una decisión de seguridad, no solo de espacio en disco?
5. ¿Qué te da LXD automáticamente (red, DNS entre instancias, almacenamiento) que en
   Docker tienes que declarar tú mismo — a mano, o dejando que Compose lo declare?
6. ¿Qué diferencia real, medible a nivel de kernel, hay entre un proceso root y un
   proceso sin privilegios dentro del mismo contenedor?

**Requisito:** haber pasado por el módulo 1 (namespaces y cgroups se mencionan ahí como
teoría; aquí se asume que sabes qué es `systemd`, `systemctl` y `journalctl`).

**Entorno:** Linux con Docker Engine y LXD ya instalados y sus daemons activos
(`systemctl status docker`, `systemctl status snap.lxd.daemon`). Si tu máquina no tiene
LXD inicializado, el Paso 0 lo resuelve.

---

## Paso 0 — Verificar el entorno (3 min)

```bash
systemctl is-active docker
systemctl is-active snap.lxd.daemon
groups   # confirma que tu usuario está en los grupos docker y lxd
```

Si `snap.lxd.daemon` está activo pero `lxc list` falla con un error sobre "root device"
o "storage pool", LXD no está inicializado todavía:

```bash
sudo lxd init --auto
lxc list   # ahora debe mostrar una tabla vacía, sin error
```

> **Nota de seguridad, no de trámite:** pertenecer al grupo `docker` (o `lxd`) equivale
> a tener acceso root efectivo sobre el host. No es una casualidad de configuración: es
> el mismo hecho que el laboratorio de Compose de este módulo te hace comprobar en su
> paso 7. Tenlo presente en cada comando `sudo` que evites usar en este laboratorio —
> muchos de ellos son innecesarios *porque* tu usuario ya tiene ese poder por otra vía.

---

## Paso 1 — Namespaces y cgroups: el sustrato compartido (10 min)

Módulo 1 los vio en teoría. Aquí los vas a ver correr.

```bash
docker run -d --name ns-demo alpine sleep 300

# Namespaces del contenedor, vistos DESDE ADENTRO (docker exec = "self" ahora es el
# proceso del contenedor)
docker exec ns-demo sh -c \
  'for ns in pid net mnt uts ipc user; do echo -n "$ns: "; readlink /proc/self/ns/$ns; done'

# Namespaces de tu propia shell, para comparar
for ns in pid net mnt uts ipc user; do echo -n "$ns: "; readlink /proc/self/ns/$ns; done
```

**Lo que deberías ver:** todos los namespaces (`pid`, `net`, `mnt`, `uts`, `ipc`) tienen
un número distinto adentro que afuera — esa es la aislación. Pero fíjate bien en `user`:
en una instalación de Docker sin *user namespace remapping* configurado (el default en
la mayoría de instalaciones), el namespace `user` **es el mismo número** adentro y
afuera. Eso es exactamente lo que el laboratorio de Compose te hace comprobar de otra
forma en su paso 7: sin remapping, "root dentro del contenedor" y "root en el host" son,
a nivel de kernel, la misma identidad.

**Salida real de esta máquina** (los números de inodo van a ser distintos en la tuya —
lo que importa es el patrón: cinco valores diferentes, uno igual):

```
--- adentro del contenedor ---
pid: pid:[4026533981]
net: net:[4026534027]
mnt: mnt:[4026533890]
uts: uts:[4026533973]
ipc: ipc:[4026533979]
user: user:[4026531837]
--- tu shell (host) ---
pid: pid:[4026531836]
net: net:[4026531833]
mnt: mnt:[4026531832]
uts: uts:[4026531838]
ipc: ipc:[4026531839]
user: user:[4026531837]
```

Fíjate: `user` es `4026531837` en ambas — idéntico. Los otros cinco no coinciden en
ningún caso.

Ahora el cgroup:

```bash
docker exec ns-demo cat /proc/self/cgroup
cat /proc/self/cgroup
```

El contenedor ve `0::/` — su propia raíz de cgroup, aislada por el namespace de cgroup.
Tu shell ve una ruta larga anidada bajo tu sesión de usuario. Es la misma jerarquía de
cgroups v2 del kernel, dos vistas distintas de ella.

**Salida real de esta máquina:**

```
--- cgroup del contenedor ---
0::/
--- cgroup de tu shell ---
0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-spawn-<uuid>.scope
```

(la ruta exacta de tu shell va a depender de tu sesión gráfica/terminal — lo que importa
es que el contenedor ve `0::/` y tú ves algo largo y anidado).

```bash
docker exec ns-demo uname -r
uname -r
```

Estas dos líneas deben imprimir **exactamente lo mismo**. Guárdalo en la cabeza: un
contenedor Docker no tiene su propio kernel. Corre sobre el kernel del host, aislado por
namespaces y limitado por cgroups. Esto es cierto para Docker y, como vas a comprobar en
el Paso 3, también para un contenedor de LXC/LXD — y **deja de ser cierto** en el Paso 4.

```bash
docker rm -f ns-demo
```

---

## Paso 2 — Dos daemons, un solo systemd (7 min)

Docker y LXD no son mecanismos distintos a nivel de kernel — son dos programas de
espacio de usuario (*daemons*) que hablan con el mismo kernel de formas distintas. Ambos
corren gestionados por `systemd`, exactamente como cualquier otro servicio que viste en
el módulo 1.

```bash
systemctl status docker --no-pager -l | head -12
systemctl status snap.lxd.daemon --no-pager -l | head -12
```

Fíjate en tres cosas que los dos tienen en común (y que el módulo 1 ya te enseñó a leer):
- **`TriggeredBy:`** — ambos son *socket-activated*: no arrancan hasta que algo toca su
  socket Unix. Esto es un patrón estándar de systemd, no algo específico de contenedores.
- **`CGroup:`** — el propio daemon vive dentro de un cgroup (`docker.service`,
  `snap.lxd.daemon.service`), controlado por el mismo mecanismo que aísla los contenedores
  que ese daemon crea.
- **`Memory:`** — compara el consumo en reposo de los dos daemons en tu máquina. No hay
  un ganador universal (cambia según versión y carga); lo que importa es que ambos son
  procesos de Linux corrientes, visibles y medibles con las mismas herramientas.

```bash
journalctl -u docker --no-pager | tail -15
journalctl -u snap.lxd.daemon --no-pager | tail -15
```

Mismo comando, mismo formato de log, dos daemons distintos. Si `docker logs` o `lxc
info` alguna vez no te dan suficiente contexto sobre por qué algo falló, `journalctl -u
<servicio>` es tu primer paso — otra vez, módulo 1.

---

## Paso 3 — LXC/LXD: un contenedor **de sistema** (12 min)

Hasta aquí, "contenedor" significó un solo proceso (`sleep 300`). Eso es un
**contenedor de aplicación** — el modelo por defecto de Docker: una imagen empaqueta un
proceso (o unos pocos, vía sidecar), y cuando ese proceso muere, el contenedor muere.

LXC/LXD parte de una idea distinta: **contenedor de sistema**. En vez de un proceso,
empaqueta y arranca un sistema Linux completo — con su propio `init`, sus propios
servicios systemd, su propio `cron`, su propio `dbus` — todo compartiendo el kernel del
host, igual que Docker.

```bash
lxc launch ubuntu:24.04 c1
lxc list
```

Espera unos segundos a que tenga IP y compara:

```bash
lxc exec c1 -- uname -r
uname -r
```

Igual que con Docker: mismo kernel. Un contenedor de sistema **tampoco** es una máquina
virtual. Ahora la diferencia real:

```bash
lxc exec c1 -- ps aux | head -10
lxc exec c1 -- systemctl is-system-running
```

Vas a ver `/sbin/init` como PID 1, y detrás de él `systemd-journald`,
`systemd-udevd`, `systemd-resolved`, `systemd-networkd`, `cron`, `dbus` — un sistema
completo arrancando adentro.

**Salida real de esta máquina** (`ps aux` dentro de `c1`, primeras líneas):

```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0  21992 13364 ?        Ss   21:16   0:00 /sbin/init
root          53  0.0  0.0  33972 14156 ?        Ss   21:16   0:00 /usr/lib/systemd/systemd-journald
root         112  0.0  0.0  25320  7544 ?        Ss   21:16   0:00 /usr/lib/systemd/systemd-udevd
systemd+     197  0.0  0.0  21476 13280 ?        Ss   21:16   0:00 /usr/lib/systemd/systemd-resolved
systemd+     420  0.0  0.0  19008  9552 ?        Ss   21:16   0:00 /usr/lib/systemd/systemd-networkd
root         458  0.0  0.0   7232  2748 ?        Ss   21:16   0:00 /usr/sbin/cron -f -P
message+     459  0.0  0.0   9600  5396 ?        Ss   21:16   0:00 @dbus-daemon --system --address=systemd: ...
```

Compáralo con el `ps aux` de `ns-demo` en el Paso 1: ahí solo hubieras visto una línea
(`sleep 300`). Aquí hay un sistema completo. `systemctl is-system-running` puede responder `starting`
si lo corres en los primeros segundos (el sistema adentro todavía está arrancando
servicios, igual que le pasaría a una máquina física recién encendida); espera unos
segundos y repite el comando hasta que responda `running`:

```bash
until lxc exec c1 -- systemctl is-system-running 2>/dev/null | grep -q running; do sleep 2; done
lxc exec c1 -- systemctl is-system-running
```

Esa es la diferencia entre contenedor de aplicación y contenedor de sistema, vista, no
leída.

```bash
lxc delete c1 --force
```

---

## Paso 4 — LXC/LXD: la misma herramienta, ahora una VM real (10 min)

La misma CLI (`lxc`) que acabas de usar para lanzar un contenedor de sistema también
sabe lanzar una **máquina virtual ligera**, con un solo flag:

```bash
time lxc launch ubuntu:24.04 v1 --vm
lxc list
```

Anota cuánto tardó frente a los ~1-2 segundos que tardó `c1` en el paso anterior (una
vez la imagen ya estaba en caché local). Ahora la prueba de que esto es virtualización
de verdad, no un contenedor con otro nombre:

```bash
lxc exec v1 -- uname -r
uname -r
```

**Estas dos líneas deben ser DIFERENTES.** `v1` corre su propio kernel de invitado,
separado del kernel de tu host — al revés de todo lo que viste en los pasos 1 y 3.

**Salida real de esta máquina:**

```
--- kernel dentro de v1 (invitado) ---
6.8.0-136-generic
--- kernel de tu host ---
6.17.0-1032-oem
```

```bash
lxc exec v1 -- systemd-detect-virt
```

Debe responder `kvm`: adentro de la VM, el propio sistema reconoce que está corriendo
sobre un hipervisor. Corre el mismo comando en tu host (fuera de cualquier contenedor o
VM) y compara:

```bash
systemd-detect-virt
```

En tu host debería responder `none` (a menos que tu propia máquina ya sea una VM).
Confirmado en esta máquina: `kvm` adentro de `v1`, `none` en el host.

**La tabla que resume los pasos 1, 3 y 4:**

| | `docker run` | `lxc launch` (contenedor) | `lxc launch --vm` |
|---|---|---|---|
| Kernel | compartido con el host | compartido con el host | **propio**, vía KVM |
| Qué arranca | 1 proceso | sistema completo (`init`, systemd) | sistema completo, virtualizado |
| Aislamiento | namespaces + cgroups | namespaces + cgroups | virtualización de hardware (KVM) |
| Arranque | instantáneo | ~1–2 s | ~15–35 s |
| Modelo | contenedor de **aplicación** | contenedor de **sistema** | máquina virtual **ligera** |

```bash
lxc delete v1 --force
```

---

## Paso 5 — OCI, Docker Hub y por qué el tamaño de una imagen importa (10 min)

**OCI** (Open Container Initiative) es la especificación que define el formato de una
imagen de contenedor y el formato de un runtime que la ejecuta — es lo que hace que una
imagen construida con `docker build` pueda correr con `containerd`, `podman` o cualquier
otro runtime compatible, sin depender de Docker específicamente. Las imágenes que jalas
con `docker pull` son imágenes OCI. Las imágenes de LXC/LXD (los `ubuntu:24.04` que
lanzaste en los pasos 3 y 4) **no son imágenes OCI** — vienen del servidor de imágenes
propio de Linux Containers (`images:` / `ubuntu:`), con su propio formato de rootfs.
Son dos ecosistemas de imágenes distintos, aunque ambos empaquetan un sistema de
archivos Linux.

```bash
docker pull -q python:3.13
docker pull -q python:3.13-slim
docker pull -q alpine:3.20
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "python|alpine|REPOSITORY"
```

Mira la diferencia de tamaño entre `python:3.13` y `python:3.13-slim` — no es un
detalle cosmético: cada paquete de más en una imagen es superficie de ataque de más
(más CVEs potenciales, más cosas que un atacante puede usar si logra ejecutar código
adentro). El laboratorio de Compose de este módulo lo lleva al extremo con imágenes
`distroless` (sin ni siquiera un shell adentro).

Fíjate en que el `-q` (quiet) de los tres comandos anteriores no solo silencia la barra
de progreso: su salida es justamente el nombre completo con el que Docker resolvió cada
imagen, por ejemplo:

```
docker.io/library/python:3.13
```

El segmento `library/` es la
señal: son las **imágenes oficiales** de Docker Hub, mantenidas con revisión de
seguridad y actualizadas activamente por Docker o por el proyecto upstream. Una imagen
de un usuario o de una organización cualquiera (ej. `docker.io/algun-usuario/su-imagen`)
no pasa por esa curación — puede ser perfectamente confiable, o puede no serlo. La buena
práctica no es "nunca uses una imagen que no sea `library/`", es: **antes de poner una
imagen en producción, mira explícitamente en qué namespace vive y quién la mantiene** —
no lo asumas por el nombre bonito del repositorio.

```bash
docker rmi python:3.13 python:3.13-slim alpine:3.20
```

---

## Paso 6 — Red y almacenamiento: qué te da LXD gratis y qué te da Compose (12 min)

Módulo aparte: el laboratorio de Compose de este módulo ya te hace escribir una red y
un volumen con nombre explícito (sus prácticas #3 y #4). Aquí no repetimos eso — aquí
comparamos **qué tan automático es** en cada modelo.

**LXD gestiona red y almacenamiento a nivel de instalación, no por proyecto:**

```bash
lxc network show lxdbr0
lxc storage show default
```

**Salida real de esta máquina** (recortada a lo esencial):

```
$ lxc network show lxdbr0
name: lxdbr0
type: bridge
managed: true
config:
  ipv4.address: 10.70.168.1/24
  ipv4.nat: "true"
used_by:
- /1.0/profiles/default

$ lxc storage show default
name: default
driver: dir
config:
  source: /var/snap/lxd/common/lxd/storage-pools/default
used_by:
- /1.0/profiles/default
```

Cada instancia que lanzas se conecta a `lxdbr0` y usa el pool `default` sin que tengas
que declarar nada — lo viste ya en los pasos 3 y 4 sin darte cuenta.

**Y la resolución de nombres entre instancias también viene incluida:**

```bash
lxc launch ubuntu:24.04 c1
lxc launch ubuntu:24.04 c2
sleep 8   # a que ambas tengan IP
lxc exec c1 -- ping -c2 c2
```

`c1` le hace ping a `c2` **por nombre**, sin haber configurado DNS ni red: LXD resuelve
`<nombre-de-instancia>.lxd` automáticamente entre todo lo que corre en el mismo proyecto.

**Salida real de esta máquina:**

```
PING c2 (fd42:62a9:e9db:6dda:216:3eff:fe22:e38e) 56 data bytes
64 bytes from c2.lxd (fd42:62a9:e9db:6dda:216:3eff:fe22:e38e): icmp_seq=1 ttl=64 time=0.095 ms
64 bytes from c2.lxd (fd42:62a9:e9db:6dda:216:3eff:fe22:e38e): icmp_seq=2 ttl=64 time=0.063 ms

--- c2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1061ms
```

Fíjate en `c2.lxd` — LXD resolvió el nombre solo, sin ningún paso de configuración de tu
parte.

Ahora el contraste con Docker. Un `docker run` normal, sin Compose, **no** te da eso:

```bash
docker run -d --name web alpine sleep 300
docker run -d --name client alpine sleep 300
docker exec client ping -c2 web
```

Vas a ver `ping: bad address 'web'` (confirmado en esta máquina: exactamente ese
mensaje). La red *default* de Docker (el bridge `docker0`) no
tiene DNS embebido entre contenedores — es una limitación real y conocida, no un error
tuyo. Ahora compara con un `compose.yaml` mínimo:

```bash
mkdir -p /tmp/lab-compose && cd /tmp/lab-compose
cat > compose.yaml <<'EOF'
services:
  web:
    image: alpine
    command: sleep 300
  client:
    image: alpine
    command: sleep 300
    depends_on:
      - web
EOF
docker compose up -d
docker compose exec client ping -c2 web
```

Esta vez sí responde. **Salida real de esta máquina:**

```
PING web (172.22.0.2): 56 data bytes
64 bytes from 172.22.0.2: seq=0 ttl=64 time=0.048 ms
64 bytes from 172.22.0.2: seq=1 ttl=64 time=0.105 ms

--- web ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
```

La diferencia no es que Compose "sepa hacer algo mágico": Compose
crea automáticamente una red *bridge* con nombre propio para tu proyecto (revisa
`docker network ls` y busca `lab-compose_default`), y esa red sí tiene DNS embebido. Es
la misma primitiva de Docker (una red *user-defined*) que tú mismo declaras a mano en
el laboratorio de Compose de este módulo — aquí ves qué pasa cuando esa declaración
falta.

```bash
docker compose down
cd - && rm -rf /tmp/lab-compose
docker rm -f web client 2>/dev/null
lxc delete c1 --force
lxc delete c2 --force
```

**La comparación en una frase:** LXD te da red y DNS entre instancias por defecto, a
nivel de todo el host; Docker te da aislamiento por contenedor por defecto, y **tú**
declaras la red (a mano, o dejando que Compose la declare por ti) cuando quieres que
varios contenedores se hablen por nombre. Ninguno de los dos modelos es "mejor" — son
default distintos para casos de uso distintos.

---

## Paso 7 — Por qué el tamaño de la imagen y el usuario del proceso son decisiones de seguridad (15 min)

Ya viste en el Paso 5 que `python:3.13` pesa 9× más que `python:3.13-slim`. Ahora vas a
medir **qué compra ese peso extra**, no solo en disco.

### 7.1 — Vulnerabilidades: escanea las tres imágenes con Trivy

```bash
docker pull -q python:3.13
docker pull -q python:3.13-slim
docker pull -q alpine:3.20

trivy image --scanners vuln --severity HIGH,CRITICAL -q python:3.13        | grep "^Total:" | head -1
trivy image --scanners vuln --severity HIGH,CRITICAL -q python:3.13-slim   | grep "^Total:" | head -1
trivy image --scanners vuln --severity HIGH,CRITICAL -q alpine:3.20        # esta imprime "0" en la tabla, no una línea "Total:"
```

> Trivy imprime **dos** líneas `Total:` para las imágenes de Python: la primera (la que
> capturamos con `head -1`) cuenta las vulnerabilidades del sistema operativo base
> (paquetes Debian); una segunda, más abajo, cuenta solo las bibliotecas de Python
> instaladas con `pip`. Si corres el comando sin el `grep`, vas a ver ambas — la tabla
> de abajo usa la primera, que es la que cambia drásticamente entre `python:3.13` y
> `python:3.13-slim`.

En la corrida de referencia de este laboratorio (re-confirmada en esta máquina el
2026-08-14 con la base de datos de vulnerabilidades de Trivy actualizada ese mismo día —
**tu número exacto va a ser distinto** porque la base de datos de CVEs cambia todos los
días; lo que no cambia es el patrón):

| Imagen | Tamaño | HIGH + CRITICAL |
|---|---|---|
| `python:3.13` | 1.62 GB | 438 (378 HIGH, 60 CRITICAL) |
| `python:3.13-slim` | 178 MB | 23 (19 HIGH, 4 CRITICAL) |
| `alpine:3.20` | 12.2 MB | 0 |

No es coincidencia ni casualidad de esta corrida: la imagen `python:3.13` completa trae
un sistema operativo Debian entero con cientos de paquetes que tu aplicación jamás usa
(herramientas de compilación, utilidades de red, documentación, bibliotecas de
gráficos). Cada paquete de esos, lo uses o no, es una superficie de vulnerabilidades que
heredas. `slim` recorta la mayoría; Alpine (basada en musl + BusyBox, un conjunto de
paquetes deliberadamente mínimo) casi los elimina. El laboratorio de Compose de este
módulo lleva esta misma idea un paso más allá con `distroless`.

```bash
docker rmi python:3.13 python:3.13-slim alpine:3.20
```

### 7.2 — Root dentro del contenedor: qué puede hacer y qué no

```bash
docker run --rm alpine sh -c \
  'echo "UID: $(id -u) ($(whoami))"; apk add --no-cache curl >/dev/null 2>&1 && echo "instalar paquete: OK" || echo "instalar paquete: FALLÓ"'

docker run --rm --user 1000:1000 alpine sh -c \
  'echo "UID: $(id -u)"; apk add --no-cache curl >/dev/null 2>&1 && echo "instalar paquete: OK" || echo "instalar paquete: FALLÓ"'
```

Como root (el *default* si no pones `--user`), instalar un paquete funciona. Con
`--user 1000:1000`, falla — el UID 1000 no tiene permiso de escritura en `/etc` ni en
`/lib/apk`, exactamente como le pasaría a un usuario sin privilegios en cualquier Linux.

**Salida real de esta máquina:**

```
=== como root ===
UID: 0 (root)
instalar paquete: OK
=== como UID 1000 ===
UID: 1000
instalar paquete: FALLÓ
```

Ahora la evidencia a nivel de kernel, no solo de permisos de archivo:

```bash
docker run --rm alpine sh -c 'grep CapEff /proc/self/status'
docker run --rm --user 1000:1000 alpine sh -c 'grep CapEff /proc/self/status'
```

**Salida real de esta máquina:**

```
=== CapEff como root ===
CapEff:	00000000a80425fb
=== CapEff como UID 1000 ===
CapEff:	0000000000000000
```

Decodificado con `capsh --decode=00000000a80425fb` en esta misma máquina:
`cap_chown, cap_dac_override, cap_fowner, cap_fsetid, cap_kill, cap_setgid, cap_setuid,
cap_setpcap, cap_net_bind_service, cap_net_raw, cap_sys_chroot, cap_mknod,
cap_audit_write, cap_setfcap`.

La máscara de capacidades de Linux (`CapEff`) del proceso root **no es cero**: trae
capacidades reales como `cap_net_bind_service` (abrir puertos <1024),
`cap_sys_chroot`, `cap_setuid`/`cap_setgid` (cambiar de identidad), `cap_dac_override`
(saltarse permisos de archivo) — las cuatro confirmadas arriba, entre las catorce que
Docker concede por defecto. La del proceso no-root es literalmente
`0000000000000000` — cero capacidades especiales, aunque el contenedor haya sido
comprometido, un atacante que ejecute código ahí adentro no tiene ninguna de esas
palancas.

> Esta es la razón técnica exacta detrás de la práctica #5 del laboratorio de Compose
> de este módulo (`cap_drop: [ALL]` + añadir solo lo estrictamente necesario) y detrás
> del hallazgo del Paso 1 de este laboratorio (namespace `user` compartido = root del
> contenedor puede ser root del host). Un `Dockerfile` con una línea `USER 1000` al
> final, o un `compose.yaml` con `user: "1000:1000"`, no es una formalidad — es la
> diferencia entre estas dos máscaras de capacidades.

---

## Síntesis — las cuatro piezas, una tabla

| Término | Qué es | Qué NO es |
|---|---|---|
| **OCI** | especificación de formato de imagen y de runtime de contenedores | un programa que se instala; es un estándar |
| **Docker** | motor + CLI que construye y corre imágenes OCI como contenedores de **aplicación** | un mecanismo de aislamiento nuevo (usa namespaces/cgroups del kernel, igual que todo lo demás) |
| **LXC** | interfaz de espacio de usuario a namespaces/cgroups del kernel, orientada a contenedores de **sistema** | un formato de imagen OCI |
| **LXD** | daemon y CLI (`lxc`) que gestiona LXC **y además** máquinas virtual ligeras vía KVM, con la misma interfaz | solo un envoltorio de LXC — desde el Paso 4 sabes que también virtualiza de verdad |

---

## Cómo conecta con el resto del curso

- **Módulo 1:** los namespaces y cgroups que ahí fueron teoría (`systemd`,
  `journalctl`, gestión de servicios) son exactamente lo que acabas de operar en los
  Pasos 1 y 2, en dos daemons distintos.
- **Este mismo módulo (Compose):** el hallazgo del Paso 1 sobre el namespace `user`
  compartido es la misma verdad de fondo que el paso 7 del laboratorio de Compose
  comprueba desde otro ángulo (pertenecer al grupo `docker` = ser root en el host).
- **Módulo 5 (CKA):** un Pod de Kubernetes, por debajo, es un grupo de contenedores de
  **aplicación** (el modelo del Paso 1 y 3, no el del Paso 4) compartiendo namespaces
  entre sí. El 30% de troubleshooting de CKA empieza exactamente en el runtime del nodo
  que acabas de inspeccionar aquí.
- **Módulo 7 (CKS):** el `CapEff` en cero del Paso 7 es el mismo principio detrás de
  `securityContext.runAsNonRoot` y `capabilities.drop` en un `PodSecurityContext` de
  Kubernetes — CKS dedica un dominio completo a exactamente esta decisión, ahora ya la
  viste funcionar a nivel de un solo contenedor Docker.

---

## Para profundizar

Este laboratorio se apoya solo en lo que pudiste observar directamente en tu propia
terminal. Lo que sigue es material de enriquecimiento conceptual — gobernanza, historia
de proyecto, estudios publicados — que un comando de terminal no puede darte. Viene del
research de Gemini en
[`research/deep-research-oci-lxc-lxd.md`](./research/deep-research-oci-lxc-lxd.md),
auditado claim por claim contra sus fuentes primarias antes de entrar aquí (ver
[`research/deep-research-oci-lxc-lxd.AUDIT.md`](./research/deep-research-oci-lxc-lxd.AUDIT.md)
para el detalle de qué se descartó y por qué — incluye una cadencia de parches de Docker
Hub que el reporte presentó como política oficial y resultó ser un hilo de queja de un
usuario, no una política).

**OCI (Open Container Initiative).** Se fundó el 22 de junio de 2015 en DockerCon San
Francisco, bajo el paraguas de The Linux Foundation, cuando Docker donó el código de
`libcontainer` (refactorizado como `runc`) y CoreOS aportó el liderazgo técnico de su
iniciativa rival *appc*, para evitar una fragmentación del ecosistema entre dos
estándares de contenedores competidores. Hoy mantiene tres especificaciones: la
`runtime-spec` y la `image-spec` (v1.0, julio 2017) y la `distribution-spec` (v1.0, mayo
2021). Su gobernanza separa el **Trademark Board** (marcas, membresía) del **Technical
Oversight Board** (arbitraje técnico entre proyectos), delegando el trabajo diario a una
comunidad abierta de desarrolladores (la TDC). (Fuente:
opencontainers.org/posts/announcements/ — buscar el post de junio 2015 y el
`CHARTER.md` de github.com/opencontainers/tob.)

**LXC.** El proyecto nació en 2008 para darle una interfaz de espacio de usuario
coherente a las primitivas de kernel (cgroups, namespaces) que venían apareciendo desde
2006. Sigue activamente mantenido bajo el paraguas comunitario de linuxcontainers.org,
con lanzamientos LTS de cinco años de soporte cada uno: LXC 5.0 (2022, soporte hasta
junio 2027), LXC 6.0 (abril 2024, hasta junio 2029) y LXC 7.0 (abril 2026, hasta junio
2031). (Fuente: linuxcontainers.org/lxc/news/.)

**LXD → Incus: la bifurcación real.** Esta es la historia que este laboratorio te pidió
investigar con más cuidado, sin suavizar si resultaba incómoda — y resultó ser cierta.
LXD nació en Canonical (anunciado noviembre 2014) y vivió más de ocho años como
subproyecto de la comunidad linuxcontainers.org. El 4 de julio de 2023, Canonical
decidió unilateralmente sacar LXD de esa infraestructura comunitaria hacia sus propios
dominios (`github.com/canonical/lxd`, `ubuntu.com/lxd`); el mantenedor histórico,
Stéphane Graber, dejó Canonical ese mismo mes. En diciembre de 2023, Canonical
relicenció LXD de Apache 2.0 a **AGPLv3** y exigió a cualquier colaborador externo
firmar un **Contributor License Agreement (CLA)** que le transfiere derechos a
Canonical. La comunidad respondió con un fork: **Incus**, creado por Aleksa Sarai a
partir de LXD 5.16 y adoptado por linuxcontainers.org el 7 de agosto de 2023, mantenido
por el equipo histórico completo de LXD (Graber, Christian Brauner, Serge Hallyn, Tycho
Andersen, más Sarai), bajo Apache 2.0 sin CLA (usa el estándar DCO en su lugar). Incus
0.1 salió el 7 de octubre de 2023. (Fuente: linuxcontainers.org/lxd/ y
linuxcontainers.org/incus/announcement/ — nota: el relato de la relicencia viene de un
post del propio equipo de Linux Containers describiendo la decisión de Canonical, no de
un comunicado oficial de Canonical.)

**Docker Hub — "imágenes oficiales".** El programa opera bajo el namespace `library/`
(ej. `library/python`), gestionado públicamente en
`github.com/docker-library/official-images`. Los criterios: solo software libre y de
código abierto, compromiso de mantenimiento upstream, versiones fijadas, y ninguna
imagen oficial puede construirse (`FROM`) sobre una imagen no oficial (salvo `scratch` u
otra imagen oficial) — todo construido con la herramienta `bashbrew` para soporte
multi-arquitectura. (Fuente: README de `github.com/docker-library/official-images/`. No
existe una cadencia de reconstrucción declarada públicamente — ver el AUDIT para el
detalle de por qué esa cifra específica se descartó.)

**NIST SP 800-190.** La guía "Application Container Security Guide" (Souppaya, Morello,
Scarfone; septiembre 2017) recomienda imágenes base minimalistas para reducir la
superficie de ataque de un contenedor. (Fuente: csrc.nist.gov/pubs/sp/800/190/final.)

**"Contenedor de sistema" vs "contenedor de aplicación".** La documentación oficial de
Incus (linuxcontainers.org) usa exactamente estos términos: *"System containers run full
Linux distributions using a shared kernel... very similar to a virtual machine but
sharing kernel with the host system."* vs *"Application containers run a single
application through a pre-built image... popularized by the likes of Docker and
Kubernetes."* (Fuente: linuxcontainers.org/incus/docs/main/explanation/instances/ —
verificado palabra por palabra contra la página en vivo.)

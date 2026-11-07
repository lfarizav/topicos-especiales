// Mapa del curso: figura isométrica estática para el README principal.
// Uso: node build.mjs            -> escribe ../mapa-del-curso-claro.svg y ../mapa-del-curso-oscuro.svg
//      node build.mjs --modulo N -> variante "estás aquí" del módulo N (1..9) en ../modulos/mapa-modulo-N-{claro,oscuro}.svg
//      node build.mjs --html     -> además escribe vista-claro.html y vista-oscuro.html (para revisar líneas)
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "./iso-kit.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..");

// ---------- variante "estás aquí" (--modulo N) ----------
const argM = process.argv.indexOf("--modulo");
const MOD = argM > -1 ? Number(process.argv[argM + 1]) : null;
if (MOD !== null && !(Number.isInteger(MOD) && MOD >= 1 && MOD <= 9)) throw new Error("--modulo espera un entero de 1 a 9");
const MOD_NAMES = { 1: "Linux", 2: "IA y especificaciones", 3: "Contenedores", 4: "Kubernetes", 5: "CKA", 6: "CKAD", 7: "Seguridad", 8: "GitOps, IaC y agentes", 9: "Helm" };
// sin --modulo devuelve el SVG intacto (mapa principal idéntico byte a byte)
const grp = (mods, svg, txt = false) => (MOD === null ? svg : `<g class="${mods.includes(MOD) ? "m-hi" : "m-lo" + (txt ? " m-txt" : "")}">${svg}</g>`);

const W = 1000;
const H = 720;

// ---------- mundo (z hacia arriba; +x a la derecha-abajo, +y a la izquierda-abajo) ----------
const G = -32; // suelo (base de las patas)
const T1 = { x: -170, y: -170, w: 340, d: 340, r: 10 }; // Linux
const T1_Z = -22, T1_TOP = 0;
const T2 = { x: -170, y: -170, w: 260, d: 260, r: 8 }; // contenedores
const T2_TOP = 20;
const T3 = { x: -170, y: -170, w: 180, d: 180, r: 6 }; // Kubernetes
const T3_TOP = 40;

const CP = { x: -162, y: -162, w: 54, d: 54, r: 3 };
const CP_H = 34;
const W1 = { x: -98, y: -162, w: 52, d: 52, r: 3 };
const W2 = { x: -162, y: -98, w: 52, d: 52, r: 3 };
const W3 = { x: -98, y: -98, w: 52, d: 52, r: 3 };
const NODE_H = 22;

const AGENT = { x: -34, y: -152, w: 24, d: 24, r: 3 };
const RECV = { x: 22, y: -162, w: 30, d: 36, r: 2 };
const RECV_H = 32;
const GIT = { x: 226, y: -166, w: 54, d: 46, r: 3 };
const GIT_H = 40;
const CRATE = { x: 234, y: -96, w: 42, d: 36, r: 1.5 };
const CRATE_H = 26;
const DESK = { x: -36, y: 186, w: 64, d: 34, r: 2 };
const DESK_H = 14;

const STAIR_X = -130, STAIR_W = 30, PATH_X = -115;

const FIT_W = 550, FIT_H = 520;
const P0 = k.fitProjection(
  [...k.boxCorners(T1, G, 0), ...k.boxCorners(GIT, G, GIT_H), ...k.boxCorners(DESK, G, 0), ...k.boxCorners(CRATE, G, 0), [0, 270, G], [-135, -135, T3_TOP + CP_H + 16]],
  FIT_W,
  FIT_H,
  { pad: 0 },
);
const P = { ...P0, origin: [P0.origin[0] + (W - FIT_W) / 2 + 22, P0.origin[1] + 112] };

const at = (p) => k.iso(p, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (pts, style) => k.dotsSvg(pts, style);
const seg = (a, b) => k.segment(a, b, P);
const depth = (p) => k.depthOf(p, P);
const view = [Math.cos(Math.PI / 4) * Math.cos(Math.PI / 6), Math.sin(Math.PI / 4) * Math.cos(Math.PI / 6), Math.sin(Math.PI / 6)];

// ---------- piezas genéricas ----------
function screws(plan, z, inset, size = 0.6) {
  const pts = k.corners(plan, inset);
  return L(pts.map(([x, y]) => k.ring(x, y, 2.4, z, P, 16)).join(""), { tone: "lo" }) + D(pts.map(([x, y]) => at([x, y, z])), { size });
}

function block(plan, z, h, { tone = "mid", lit = false, bevel = 0.6, seam = null, groove = 3 } = {}) {
  const inner = seam === null ? "" : L(k.sideSeam(plan, seam, P), { tone: "faint" });
  let out = S(k.slabOf(plan, z, h, P, 6, bevel), { tone, lit, inner });
  if (groove) out += L(k.planOutline(k.insetPlan(plan, groove), z + h, P, 6), { tone: "faint" });
  return out;
}

// caja inclinada: origen o, eje u (unidad * largo), eje v (ancho), alto h hacia arriba
function prism(o, u, v, h, { tone = "mid", lit = false } = {}) {
  const add = (a, b, s = 1) => a.map((c, i) => c + b[i] * s);
  const up = [0, 0, h];
  const c = [o, add(o, u), add(add(o, u), v), add(o, v)];
  const top = c.map((p) => add(p, up));
  const faces = [
    { pts: top, n: [0, 0, 1], kind: "top" },
    { pts: [c[0], c[1], top[1], top[0]], n: [-v[0], -v[1], 0] },
    { pts: [c[1], c[2], top[2], top[1]], n: [u[0], u[1], u[2]] },
    { pts: [c[2], c[3], top[3], top[2]], n: [v[0], v[1], 0] },
    { pts: [c[3], c[0], top[0], top[3]], n: [-u[0], -u[1], -u[2]] },
  ];
  const lightX = -Math.sin(Math.PI / 4), lightY = Math.cos(Math.PI / 4);
  const all = [...c, ...top].map(at);
  const hull = convexHull(all);
  let out = `<path class="iso-fill" d="${k.pathOf(hull, true)}"/>`;
  const creases = [];
  for (const f of faces) {
    const len = Math.hypot(...f.n) || 1;
    const n = f.n.map((x) => x / len);
    if (n[0] * view[0] + n[1] * view[1] + n[2] * view[2] <= 1e-6) continue;
    const d = k.pathOf(f.pts.map(at), true);
    if (f.kind === "top") out += `<path class="iso-top" d="${d}"/>`;
    else {
      const lt = (n[0] * lightX + n[1] * lightY + 1) / 2;
      out += `<path class="iso-shade" data-shade="${Math.min(3, Math.max(0, Math.floor(lt * 4)))}" d="${d}"/>`;
    }
    creases.push(d);
  }
  out += `<path class="iso-line iso-crease" data-tone="faint" d="${creases.join("")}"/>`;
  out += `<path class="iso-line iso-edge" data-tone="${tone}" d="${k.pathOf(hull, true)}"/>`;
  return `<g class="iso-solid"${lit ? " data-lit" : ""}>${out}</g>`;
}

function convexHull(points) {
  const p = [...points].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const q of p) { while (lower.length >= 2 && cross(lower.at(-2), lower.at(-1), q) <= 0) lower.pop(); lower.push(q); }
  for (const q of [...p].reverse()) { while (upper.length >= 2 && cross(upper.at(-2), upper.at(-1), q) <= 0) upper.pop(); upper.push(q); }
  return [...lower.slice(0, -1), ...upper.slice(0, -1)];
}

// ventilación: ranuras cerradas sobre una cara vertical
function vents(face, at0, z, count, step, { w = 10, h = 2.2 } = {}) {
  const m = k.sideMatrix(at0, z, P, face);
  let d = "";
  for (let i = 0; i < count; i++) {
    const x = i * step, r = h / 2;
    d += `M${x + r} 0h${w - h}a${r} ${r} 0 0 1 0 ${h}h${-(w - h)}a${r} ${r} 0 0 1 0 ${-h}Z`;
  }
  return `<g transform="${m}"><path class="iso-line" data-tone="lo" d="${d}"/></g>`;
}

// ---------- capa 1: Linux ----------
function terrace1() {
  const out = [`<path class="iso-halo" d="${k.haloOf(T1, G, T1_TOP - G, P)}"/>`];
  const feet = k.corners(T1, 26).sort((a, b) => depth([...a, 0]) - depth([...b, 0]));
  for (const [x, y] of feet) {
    out.push(S(k.cylinder(x, y, 9, G, 2, P, 28), { tone: "lo" }));
    out.push(S(k.cylinder(x, y, 7, G + 2, T1_Z - G - 2, P, 28), { tone: "mid" }));
  }
  out.push(block(T1, T1_Z, T1_TOP - T1_Z, { seam: -8, groove: 0, bevel: 1.2 }));
  out.push(screws(T1, T1_TOP, 9));
  // ranuras de ventilación en las dos caras visibles
  out.push(vents("left", [-150, 170], -4, 6, 14));
  out.push(vents("right", [170, 150], -4, 6, 14));
  return out.join("");
}

function terrace2() {
  const out = [`<path class="iso-halo" d="${k.haloOf(k.insetPlan(T2, 4), T1_TOP, 2, P)}" style="opacity:.5"/>`];
  out.push(block(T2, T1_TOP, T2_TOP - T1_TOP, { seam: 8, groove: 0, bevel: 1 }));
  out.push(screws(T2, T2_TOP, 8, 0.55));
  out.push(vents("right", [90, 70], 4, 5, 13, { w: 9, h: 2 }));
  return out.join("");
}

function terrace3() {
  const out = [`<path class="iso-halo" d="${k.haloOf(k.insetPlan(T3, 4), T2_TOP, 2, P)}" style="opacity:.5"/>`];
  out.push(block(T3, T2_TOP, T3_TOP - T2_TOP, { seam: 25, groove: 0, bevel: 1 }));
  out.push(L(k.planOutline(k.insetPlan(T3, 11), T3_TOP, P, 6), { tone: "faint" }));
  return out.join("");
}

// ---------- valla (CKS) ----------
const FENCE_IN = 4;
const fenceLines = (() => {
  const a = T3.x + FENCE_IN, b = T3.x + T3.w - FENCE_IN;
  const along = (n) => Array.from({ length: n + 1 }, (_, i) => a + ((b - a) * i) / n);
  const gate = [STAIR_X - 4, STAIR_X + STAIR_W + 4];
  return {
    back: [along(8).map((x) => [x, a]), along(8).map((y) => [a, y])],
    front: [along(8).map((x) => [x, b]), along(8).map((y) => [b, y])],
    gate,
  };
})();

function fence(lines, isFront) {
  const out = [];
  const [g0, g1] = fenceLines.gate;
  for (const row of lines) {
    let pts = row;
    if (isFront && row[0][1] === row[1][1]) {
      // fila delantera paralela a x: abre la puerta donde llega la escalera
      pts = row.filter(([x]) => x < g0 || x > g1).concat([[g0, row[0][1]], [g1, row[0][1]]]).sort((p, q) => p[0] - q[0]);
    }
    const sorted = [...pts].sort((p, q) => depth([...p, 0]) - depth([...q, 0]));
    // barandas entre postes consecutivos (salta el hueco de la puerta)
    let rails = "";
    for (let i = 0; i + 1 < pts.length; i++) {
      const [p, q] = [pts[i], pts[i + 1]];
      if (isFront && p[0] === g0 && q[0] === g1) continue;
      for (const z of [T3_TOP + 6, T3_TOP + 11]) rails += seg([p[0], p[1], z], [q[0], q[1], z]);
    }
    out.push(L(rails, { tone: "mid" }));
    for (const [x, y] of sorted) {
      const gatePost = isFront && (x === g0 || x === g1);
      out.push(S(k.cylinder(x, y, gatePost ? 2.4 : 1.3, T3_TOP, gatePost ? 16 : 12, P, 14), { tone: "mid", crease: "none" }));
      if (gatePost) out.push(S(k.cylinder(x, y, 3, T3_TOP + 16, 1.6, P, 16), { tone: "hi" }));
    }
  }
  return out.join("");
}

// ---------- nodos y pods ----------
function pods(node, top, litIndex = -1) {
  const out = [];
  const size = 15, gap = 6, inset = (node.w - size * 2 - gap) / 2;
  const cells = [];
  for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) cells.push([node.x + inset + i * (size + gap), node.y + inset + j * (size + gap)]);
  cells.sort((a, b) => depth([...a, 0]) - depth([...b, 0]));
  cells.forEach(([x, y], idx) => {
    const lit = idx === litIndex;
    const plan = { x, y, w: size, d: size, r: 2 };
    out.push(S(k.slabOf(plan, top, lit ? 11 : 8, P, 4, 0.5), { tone: lit ? "hi" : "mid", lit }));
    out.push(L(k.planOutline(k.insetPlan(plan, 3), top + (lit ? 11 : 8), P, 4), { tone: lit ? "mid" : "faint" }));
  });
  return out.join("");
}

function node(plan, h, { litPod = -1, etcd = false } = {}) {
  const out = [];
  out.push(block(plan, T3_TOP, h, { seam: T3_TOP + h - 5, groove: 0, bevel: 0.6 }));
  // luces de estado en la cara izquierda
  out.push(D([0, 1, 2].map((i) => at([plan.x + 6 + i * 4, plan.y + plan.d, T3_TOP + 6])), { size: 1, tone: "hi" }));
  out.push(vents("right", [plan.x + plan.w, plan.y + plan.d - 6], T3_TOP + 5, 3, 13, { w: 9, h: 2 }));
  if (etcd) {
    const [cx, cy] = [plan.x + plan.w / 2, plan.y + plan.d / 2];
    let z = T3_TOP + h;
    out.push(L(k.planOutline(k.insetPlan(plan, 4), z, P, 6), { tone: "faint" }));
    for (let i = 0; i < 3; i++) {
      out.push(S(k.cylinder(cx, cy, 10, z, 4.2, P, 36, 0.4), { tone: "mid" }));
      out.push(L(k.ring(cx, cy, 6, z + 4.2, P, 30), { tone: "faint" }));
      z += 5;
    }
    out.push(D([at([cx, cy, z - 0.8])], { size: 1, tone: "hi" }));
  } else {
    out.push(pods(plan, T3_TOP + h, litPod));
  }
  return out.join("");
}

function agent() {
  const out = [];
  const z0 = T3_TOP;
  for (const [x, y] of k.corners(AGENT, 3).sort((a, b) => depth([...a, 0]) - depth([...b, 0]))) out.push(S(k.cylinder(x, y, 1.6, z0, 5, P, 12), { tone: "mid", crease: "none" }));
  out.push(block(AGENT, z0 + 5, 14, { seam: z0 + 15, groove: 2.5 }));
  const [cx, cy] = [AGENT.x + AGENT.w / 2, AGENT.y + AGENT.d / 2];
  out.push(S(k.cylinder(cx, cy, 6.5, z0 + 19, 6, P, 32, 0.4), { tone: "mid" }));
  out.push(L(k.sideArc(cx, cy, 6.5, z0 + 22, P, 24), { tone: "faint" }));
  // ojo-sensor en la cara izquierda
  out.push(D([at([cx - 3, AGENT.y + AGENT.d, z0 + 13]), at([cx + 3, AGENT.y + AGENT.d, z0 + 13])], { size: 1.5, tone: "hi" }));
  out.push(S(k.cylinder(cx, cy, 0.8, z0 + 25, 14, P, 10), { tone: "mid", crease: "none" }));
  out.push(S(k.cylinder(cx, cy, 2.4, z0 + 39, 2.4, P, 16), { tone: "hi" }));
  return out.join("");
}

// ---------- GitOps: repositorio, cinta, receptor ----------
const BELT = { from: 52, to: 230, y0: -160, y1: -128, zHi: 48, zLo: 12 };
const beltZ = (x) => BELT.zLo + ((BELT.to - x) / (BELT.to - BELT.from)) * (BELT.zHi - BELT.zLo);

function receiver() {
  const out = [];
  out.push(block(RECV, T2_TOP, RECV_H, { seam: T2_TOP + RECV_H - 6, groove: 3 }));
  const [cx, cy] = [RECV.x + RECV.w / 2, RECV.y + RECV.d / 2];
  out.push(S(k.cylinder(cx, cy, 7, T2_TOP + RECV_H, 3, P, 30, 0.4), { tone: "mid" }));
  out.push(L(k.ring(cx, cy, 4, T2_TOP + RECV_H + 3, P, 24), { tone: "lo" }));
  out.push(D([at([cx, cy, T2_TOP + RECV_H + 3])], { size: 0.8, tone: "hi" }));
  out.push(vents("left", [RECV.x + 5, RECV.y + RECV.d], T2_TOP + 6, 2, 11, { w: 8, h: 2 }));
  return out.join("");
}

function gitCabinet() {
  const out = [`<path class="iso-halo" d="${k.haloOf(GIT, G, GIT_H, P)}"/>`];
  out.push(block(GIT, G, GIT_H, { seam: G + 12, groove: 0, bevel: 0.8 }));
  // tres cajones en la cara izquierda (+y), con tiradores
  const m = k.sideMatrix([GIT.x, GIT.y + GIT.d], G + GIT_H - 2, P, "left");
  let d = "";
  for (let i = 0; i < 2; i++) d += `M4 ${3 + i * 11}h${GIT.w - 8}v9h${-(GIT.w - 8)}Z`;
  out.push(`<g transform="${m}"><path class="iso-line" data-tone="lo" d="${d}"/><path class="iso-line" data-tone="mid" d="M${GIT.w / 2 - 5} 6.5h10a1 1 0 0 1 0 2h-10a1 1 0 0 1 0-2ZM${GIT.w / 2 - 5} 17.5h10a1 1 0 0 1 0 2h-10a1 1 0 0 1 0-2Z"/></g>`);
  // símbolo de rama en la cara derecha: un tronco y una rama que se separa y vuelve
  const mr = k.sideMatrix([GIT.x + GIT.w, GIT.y + GIT.d - 8], G + GIT_H - 6, P, "right");
  out.push(`<g transform="${mr}"><path class="iso-line" data-tone="hi" d="M8 5.6V24.4M18 9.6V12C18 17 8 15 8 20"/><circle class="iso-wire-end" cx="8" cy="4" r="1.6"/><circle class="iso-wire-end" cx="8" cy="26" r="1.6"/><circle class="iso-wire-end" cx="18" cy="8" r="1.6"/></g>`);
  out.push(vents("right", [GIT.x + GIT.w, GIT.y + 18], G + 8, 1, 0, { w: 10, h: 2 }));
  out.push(screws(GIT, G + GIT_H, 4, 0.5));
  return out.join("");
}

function conveyorLegs() {
  const out = [];
  const legs = [];
  for (const x of [110, 196]) for (const y of [BELT.y0 + 3, BELT.y1 - 3]) legs.push([x, y]);
  legs.sort((a, b) => depth([...a, 0]) - depth([...b, 0]));
  for (const [x, y] of legs) {
    const base = x < T1.x + T1.w ? T1_TOP : G;
    out.push(S(k.slabOf({ x: x - 1.6, y: y - 1.6, w: 3.2, d: 3.2, r: 0.6 }, base, beltZ(x) - 5 - base, P, 2), { tone: "mid", crease: "none" }));
    out.push(S(k.slabOf({ x: x - 3, y: y - 3, w: 6, d: 6, r: 1 }, base, 1.2, P, 2), { tone: "lo", crease: "none" }));
  }
  // travesaño entre las patas de cada par
  return out.join("");
}

function conveyor() {
  const out = [];
  const len = BELT.to - BELT.from;
  const u = [-len, 0, BELT.zHi - BELT.zLo];
  const o = [BELT.to, BELT.y0, BELT.zLo - 5];
  // bastidor
  out.push(prism(o, u, [0, BELT.y1 - BELT.y0, 0], 5, { tone: "mid" }));
  // tablillas de la cinta, de baranda a baranda
  let slats = "";
  for (let x = BELT.to - 6; x > BELT.from + 4; x -= 8) slats += seg([x, BELT.y0 + 3, beltZ(x)], [x, BELT.y1 - 3, beltZ(x)]);
  out.push(L(slats, { tone: "lo" }));
  // barandas laterales
  out.push(prism([BELT.to, BELT.y0, BELT.zLo], u, [0, 3, 0], 2.4, { tone: "mid" }));
  // commits viajando hacia el clúster
  const packets = [86, 128, 170, 208];
  for (const x of packets) {
    const plan = { x: x - 7, y: BELT.y0 + 8, w: 14, d: 16, r: 1.5 };
    out.push(S(k.slabOf(plan, beltZ(x), 8, P, 3, 0.4), { tone: "hi" }));
    out.push(L(k.planOutline(k.insetPlan(plan, 2.5), beltZ(x) + 8, P, 3), { tone: "faint" }));
  }
  out.push(prism([BELT.to, BELT.y1 - 3, BELT.zLo], u, [0, 3, 0], 2.4, { tone: "mid" }));
  // tambores en los extremos
  out.push(S(k.slabOf({ x: BELT.to - 3, y: BELT.y0 - 2, w: 6, d: BELT.y1 - BELT.y0 + 4, r: 2.5 }, BELT.zLo - 6, 7, P, 4), { tone: "mid" }));
  return out.join("");
}

function crate() {
  const out = [`<path class="iso-halo" d="${k.haloOf(CRATE, G, CRATE_H, P)}"/>`];
  out.push(block(CRATE, G, CRATE_H, { seam: G + CRATE_H - 4, groove: 0, bevel: 0.5 }));
  // tablillas verticales de borde a borde en las dos caras visibles
  let d = "";
  for (let i = 1; i < 5; i++) d += seg([CRATE.x + (CRATE.w * i) / 5, CRATE.y + CRATE.d, G], [CRATE.x + (CRATE.w * i) / 5, CRATE.y + CRATE.d, G + CRATE_H - 4]);
  for (let i = 1; i < 4; i++) d += seg([CRATE.x + CRATE.w, CRATE.y + (CRATE.d * i) / 4, G], [CRATE.x + CRATE.w, CRATE.y + (CRATE.d * i) / 4, G + CRATE_H - 4]);
  out.push(L(d, { tone: "lo" }));
  // tapa con timón (rueda de seis radios, genérica)
  const [cx, cy] = [CRATE.x + CRATE.w / 2, CRATE.y + CRATE.d / 2];
  out.push(L(k.ring(cx, cy, 9, G + CRATE_H, P, 36), { tone: "mid" }));
  let spokes = "";
  for (let i = 0; i < 6; i++) {
    const a = (i * Math.PI) / 3;
    spokes += k.lineOnTop([cx + Math.cos(a) * 2.2, cy + Math.sin(a) * 2.2], [cx + Math.cos(a) * 9, cy + Math.sin(a) * 9], G + CRATE_H, P);
  }
  out.push(L(spokes, { tone: "mid" }));
  out.push(L(k.ring(cx, cy, 2.2, G + CRATE_H, P, 16), { tone: "mid" }));
  out.push(D(k.corners(CRATE, 3).map(([x, y]) => at([x, y, G + CRATE_H])), { size: 0.6 }));
  return out.join("");
}

// ---------- capa 2 y 1: objetos en las terrazas ----------
function container(plan, z, alongX) {
  const h = 16;
  const out = [S(k.slabOf(plan, z, h, P, 2, 0.4), { tone: "mid", inner: L(k.sideSeam(plan, z + h - 2, P, 2), { tone: "faint" }) })];
  let d = "";
  if (alongX) {
    for (let x = plan.x + 3; x < plan.x + plan.w - 1; x += 3) d += seg([x, plan.y + plan.d, z], [x, plan.y + plan.d, z + h - 2]);
    const xf = plan.x + plan.w;
    d += seg([xf, plan.y + plan.d / 2, z], [xf, plan.y + plan.d / 2, z + h]);
    for (const y of [plan.y + 4, plan.y + plan.d - 4]) d += seg([xf, y, z], [xf, y, z + h]);
  } else {
    for (let y = plan.y + 3; y < plan.y + plan.d - 1; y += 3) d += seg([plan.x + plan.w, y, z], [plan.x + plan.w, y, z + h - 2]);
    const yf = plan.y + plan.d;
    d += seg([plan.x + plan.w / 2, yf, z], [plan.x + plan.w / 2, yf, z + h]);
    for (const x of [plan.x + 4, plan.x + plan.w - 4]) d += seg([x, yf, z], [x, yf, z + h]);
  }
  out.push(L(d, { tone: "lo" }));
  out.push(D(k.corners(plan, 1.2).map(([x, y]) => at([x, y, z + h])), { size: 0.7, tone: "mid" }));
  return out.join("");
}

function stairs(y, zBase, rise, depthEach = 8) {
  const out = [];
  for (let i = 0; i < 3; i++) {
    const plan = { x: STAIR_X, y, w: STAIR_W, d: depthEach * (3 - i), r: 0.6 };
    out.push(S(k.slabOf(plan, zBase + rise * i, rise, P, 2, 0.4), { tone: "mid" }));
  }
  return out.join("");
}

function stairPath(yFront, zBase, rise, depthEach = 8) {
  const pts = [[PATH_X, yFront + depthEach * 3, zBase]];
  for (let i = 0; i < 3; i++) {
    const y = yFront + depthEach * (3 - i);
    pts.push([PATH_X, y, zBase + rise * (i + 1)]);
    pts.push([PATH_X, y - depthEach, zBase + rise * (i + 1)]);
  }
  return pts;
}

function terminal() {
  const out = [];
  const base = { x: 108, y: 112, w: 44, d: 34, r: 2 };
  out.push(S(k.slabOf(base, T1_TOP, 3, P, 3, 0.4), { tone: "mid" }));
  const box = { x: 112, y: 114, w: 36, d: 24, r: 2 };
  out.push(block(box, 3, 26, { seam: 8, groove: 3 }));
  // pantalla en la cara izquierda (+y)
  const m = k.sideMatrix([box.x, box.y + box.d], 27, P, "left");
  out.push(`<g transform="${m}"><path class="iso-fill map-screen" d="M4 2.5h${box.w - 8}a1.5 1.5 0 0 1 1.5 1.5v12a1.5 1.5 0 0 1-1.5 1.5h${-(box.w - 8)}a1.5 1.5 0 0 1-1.5-1.5v-12a1.5 1.5 0 0 1 1.5-1.5Z"/><path class="iso-line" data-tone="mid" d="M4 2.5h${box.w - 8}a1.5 1.5 0 0 1 1.5 1.5v12a1.5 1.5 0 0 1-1.5 1.5h${-(box.w - 8)}a1.5 1.5 0 0 1-1.5-1.5v-12a1.5 1.5 0 0 1 1.5-1.5Z"/><text class="map-prompt" x="6" y="12.5" font-size="7">$ _</text></g>`);
  out.push(vents("right", [box.x + box.w, box.y + box.d - 4], 24, 2, 8, { w: 6, h: 1.6 }));
  // teclado
  const kb = { x: 112, y: 148, w: 36, d: 12, r: 1.5 };
  out.push(S(k.slabOf(kb, T1_TOP, 2.4, P, 3, 0.3), { tone: "mid" }));
  out.push(D(k.dotGrid(kb.x + 3, kb.y + 2.5, 11, 3, 3, 2.4, P), { size: 0.55, tone: "mid" }));
  return out.join("");
}

function ruler() {
  const strip = { x: -78, y: 154, w: 150, d: 8, r: 1 };
  const out = [S(k.slabOf(strip, T1_TOP, 0.8, P, 3), { tone: "lo", crease: "none" })];
  const t = k.topTicks(strip.x + 4, strip.x + strip.w - 4, 5, 5, strip.y + 0.8, 0.8, [2, 4], P);
  out.push(L(t.minor, { tone: "lo" }), L(t.major, { tone: "mid" }));
  return out.join("");
}

function desk() {
  const out = [`<path class="iso-halo" d="${k.haloOf(DESK, G, DESK_H, P)}"/>`];
  for (const [x, y] of k.corners(DESK, 3).sort((a, b) => depth([...a, 0]) - depth([...b, 0]))) out.push(S(k.slabOf({ x: x - 1.5, y: y - 1.5, w: 3, d: 3, r: 0.5 }, G, DESK_H - 3, P, 2), { tone: "mid", crease: "none" }));
  out.push(S(k.slabOf(DESK, G + DESK_H - 3, 3, P, 4, 0.5), { tone: "mid" }));
  const top = G + DESK_H;
  // dos documentos: el PVB (tablero de visión) y el PRD (requisitos)
  const docs = [
    { x: DESK.x + 5, y: DESK.y + 6, w: 24, d: 22, r: 1, n: 3 },
    { x: DESK.x + 34, y: DESK.y + 5, w: 24, d: 24, r: 1, n: 5 },
  ];
  for (const doc of docs) {
    for (let s = 0; s < doc.n; s++) out.push(S(k.slabOf(doc, top + s * 0.9, 0.9, P, 2), { tone: s === doc.n - 1 ? "hi" : "lo", crease: "none" }));
    const zt = top + doc.n * 0.9;
    let rules = "";
    for (let i = 0; i < 5; i++) {
      const y = doc.y + 5 + i * 3.6;
      rules += k.lineOnTop([doc.x + 4, y], [doc.x + doc.w - (i % 2 ? 8 : 4), y], zt, P);
    }
    out.push(L(rules, { tone: "lo", free: true }));
  }
  // clip del primer documento
  out.push(S(k.slabOf({ x: docs[0].x + 8, y: docs[0].y - 1.5, w: 8, d: 4, r: 1 }, top + 2.7, 1.4, P, 3), { tone: "mid" }));
  // bombilla de la idea, sobre su base
  const [bx, by] = [DESK.x + DESK.w + 22, DESK.y + 8];
  out.push(`<path class="iso-halo" d="${k.haloOf({ x: bx - 6, y: by - 6, w: 12, d: 12, r: 6 }, G, 1, P)}"/>`);
  out.push(S(k.cylinder(bx, by, 6, G, 3, P, 28, 0.4), { tone: "mid" }));
  out.push(S(k.cylinder(bx, by, 3, G + 3, 5, P, 20), { tone: "mid" }));
  out.push(L(k.sideArc(bx, by, 3, G + 5, P, 12) + k.sideArc(bx, by, 3, G + 6.6, P, 12), { tone: "lo" }));
  return { svg: out.join(""), bulb: [bx, by, G + 8] };
}

function bulbGlass([x, y, z]) {
  const [sx, sy] = at([x, y, z]);
  const r = k.screenRise(6.5, P);
  const c = [sx, sy - r * 0.95];
  const neck = r * 0.42;
  return `<g class="map-bulb"><path class="iso-fill" d="M${sx - neck} ${sy}C${sx - neck} ${sy - r * 0.35} ${c[0] - r} ${c[1] + r * 0.4} ${c[0] - r} ${c[1]}A${r} ${r} 0 1 1 ${c[0] + r} ${c[1]}C${c[0] + r} ${c[1] + r * 0.4} ${sx + neck} ${sy - r * 0.35} ${sx + neck} ${sy}Z"/><path class="iso-line" data-tone="lit" d="M${sx - neck} ${sy}C${sx - neck} ${sy - r * 0.35} ${c[0] - r} ${c[1] + r * 0.4} ${c[0] - r} ${c[1]}A${r} ${r} 0 1 1 ${c[0] + r} ${c[1]}C${c[0] + r} ${c[1] + r * 0.4} ${sx + neck} ${sy - r * 0.35} ${sx + neck} ${sy}"/><path class="iso-line" data-tone="lit" d="M${sx - neck * 0.5} ${sy - 1}L${sx - neck * 0.5} ${c[1] + 1}L${sx} ${c[1] - 2}L${sx + neck * 0.5} ${c[1] + 1}L${sx + neck * 0.5} ${sy - 1}"/></g>`;
}

// ---------- el proyecto: camino y banderas ----------
function pathLine(points) {
  return `<path class="map-path" d="${k.pathOf(points.map(at))}"/>`;
}

function flag([x, y, z]) {
  const out = [];
  out.push(S(k.cylinder(x, y, 2.6, z, 1.6, P, 18), { tone: "hi", lit: true }));
  out.push(S(k.cylinder(x, y, 0.7, z + 1.6, 16, P, 8), { tone: "hi", crease: "none", lit: true }));
  out.push(S(k.slabOf({ x: x + 0.7, y: y - 0.5, w: 10, d: 1, r: 0 }, z + 10, 7, P, 1), { tone: "hi", lit: true, crease: "none" }));
  return out.join("");
}

// ---------- etiquetas ----------
const labels = [];
function label(side, y, title, sub, anchor, { muted = false, minY = 0, mods = [] } = {}) {
  labels.push({ side, y, title, sub, anchor: at(anchor), muted, minY, mods });
}

function placeLabels() {
  // cada etiqueta a la altura de su ancla, sin solaparse (separación mínima GAP)
  const GAP = 54, TOP = 132, BOTTOM = H - 70;
  for (const side of ["left", "right"]) {
    const list = labels.filter((l) => l.side === side).sort((a, b) => a.anchor[1] - b.anchor[1]);
    let prev = -Infinity;
    for (const l of list) { l.y = Math.max(TOP, l.minY, l.anchor[1] + 5, prev + GAP); prev = l.y; }
    const over = prev - BOTTOM;
    if (over > 0) for (let i = list.length - 1, floor = BOTTOM; i >= 0; i--) { list[i].y = Math.min(list[i].y, floor); floor = list[i].y - GAP; }
  }
}

function labelsSvg() {
  placeLabels();
  const out = [];
  for (const l of labels) {
    const left = l.side === "left";
    const tx = left ? 32 : W - 32;
    const anchor = left ? "start" : "end";
    const titleW = l.title.length * 8.4;
    const subW = l.sub.length * 7.0;
    const wEnd = left ? tx + titleW + 10 : tx - titleW - 10;
    const [ax, ay] = l.anchor;
    const elbow = left ? Math.min(ax - 14, wEnd + 30) : Math.max(ax + 14, wEnd - 30);
    const ly = l.y - 5;
    // ancla muy por encima de la etiqueta: baja en vertical y luego gira hacia el texto
    const route = ly - ay > 30 ? `M${wEnd.toFixed(1)} ${ly.toFixed(1)}H${ax.toFixed(1)}V${ay.toFixed(1)}` : `M${wEnd.toFixed(1)} ${ly.toFixed(1)}H${elbow.toFixed(1)}L${ax.toFixed(1)} ${ay.toFixed(1)}`;
    const one = [];
    one.push(`<g class="map-wire${l.muted ? " is-muted" : ""}"><path d="${route}"/><circle cx="${ax.toFixed(1)}" cy="${ay.toFixed(1)}" r="2.6"/><circle class="map-wire-start" cx="${wEnd.toFixed(1)}" cy="${(l.y - 5).toFixed(1)}" r="1.6"/></g>`);
    one.push(`<text class="map-label${l.muted ? " is-muted" : ""}" x="${tx}" y="${l.y}" text-anchor="${anchor}">${l.title}</text>`);
    one.push(`<text class="map-sub" x="${tx}" y="${l.y + 18}" text-anchor="${anchor}">${l.sub}</text>`);
    out.push(grp(l.mods, one.join(""), true));
  }
  return out.join("");
}

function milestone(text, anchor, dx, dy, anchorSide = "start", mods = []) {
  const [x, y] = at(anchor);
  return grp(mods, `<text class="map-milestone" x="${(x + dx).toFixed(1)}" y="${(y + dy).toFixed(1)}" text-anchor="${anchorSide}">${text}</text>`, true);
}

// ---------- composición ----------
const deskParts = desk();
const PIN_IDEA = [DESK.x + DESK.w + 18, DESK.y + DESK.d + 22, G];
const PIN_PVB = [DESK.x - 34, DESK.y + DESK.d + 16, G];
const PIN_PRD = [PATH_X + 6, 58, T2_TOP];
const PIN_UNITS = [PATH_X + 6, -20, T3_TOP];
const LIT_POD_TOP = T3_TOP + NODE_H + 11;
const podSize = 15, podInset = (W3.w - podSize * 2 - 6) / 2;
const LIT_POD = [W3.x + podInset + podSize + 6 + podSize / 2, W3.y + podInset + podSize + 6 + podSize / 2];
const PIN_DEPLOY = [LIT_POD[0], LIT_POD[1], LIT_POD_TOP];

const pathGround = [PIN_IDEA, [PIN_PVB[0], PIN_IDEA[1], G], PIN_PVB, ...stairPath(170, G, (T1_TOP - G) / 3)];
const pathT1 = [[PATH_X, 170, T1_TOP], ...stairPath(90, T1_TOP, (T2_TOP - T1_TOP) / 3)];
const pathT2 = [[PATH_X, 90, T2_TOP], [PATH_X, PIN_PRD[1], T2_TOP], PIN_PRD, [PATH_X, PIN_PRD[1], T2_TOP], ...stairPath(10, T2_TOP, (T3_TOP - T2_TOP) / 3)];
const pathT3 = [[PATH_X, 10, T3_TOP], [PATH_X, PIN_UNITS[1], T3_TOP], PIN_UNITS, [W3.x + 10, PIN_UNITS[1], T3_TOP], [W3.x + 10, W3.y + W3.d, T3_TOP], [W3.x + 10, W3.y + W3.d, T3_TOP + NODE_H], [LIT_POD[0], W3.y + W3.d - 4, T3_TOP + NODE_H]];

const containersT2 = [
  { plan: { x: -82, y: 48, w: 38, d: 20, r: 1 }, alongX: true },
  { plan: { x: -38, y: 48, w: 38, d: 20, r: 1 }, alongX: true },
  { plan: { x: 6, y: 48, w: 38, d: 20, r: 1 }, alongX: true },
  { plan: { x: 56, y: -100, w: 20, d: 38, r: 1 }, alongX: false },
  { plan: { x: 56, y: -50, w: 20, d: 38, r: 1 }, alongX: false },
].sort((a, b) => depth([a.plan.x + a.plan.w, a.plan.y + a.plan.d, 0]) - depth([b.plan.x + b.plan.w, b.plan.y + b.plan.d, 0]));

const nodes = [
  { at: CP, mods: [5], svg: () => node(CP, CP_H, { etcd: true }) },
  { at: W1, mods: [6], svg: () => node(W1, NODE_H) },
  { at: W2, mods: [6], svg: () => node(W2, NODE_H) },
  { at: AGENT, mods: [8], svg: agent },
  { at: W3, mods: [6], svg: () => node(W3, NODE_H, { litPod: 3 }) },
].sort((a, b) => depth([a.at.x + a.at.w, a.at.y + a.at.d, 0]) - depth([b.at.x + b.at.w, b.at.y + b.at.d, 0]));

// cada pieza se asocia a su módulo (solo importa con --modulo)
const art = [
  grp([1], terrace1()),
  grp([3], terrace2()),
  grp([4], terrace3()),
  grp([7], fence(fenceLines.back, false)),
  ...nodes.map((n) => grp(n.mods, n.svg())),
  grp([4], pathLine(pathT3)),
  grp([4], flag(PIN_UNITS)),
  grp([8], flag(PIN_DEPLOY)),
  grp([7], fence(fenceLines.front, true)),
  grp([8], receiver()),
  grp([8], conveyorLegs()),
  grp([8], gitCabinet()),
  grp([8], conveyor()),
  grp([4], stairs(10, T2_TOP, (T3_TOP - T2_TOP) / 3)),
  grp([2], pathLine(pathT2)),
  grp([2], flag(PIN_PRD)),
  ...containersT2.map((c) => grp([3], container(c.plan, T2_TOP, c.alongX))),
  grp([3], stairs(90, T1_TOP, (T2_TOP - T1_TOP) / 3)),
  grp([1], pathLine(pathT1)),
  grp([1], ruler()),
  grp([1], terminal()),
  grp([9], crate()),
  grp([1], stairs(170, G, (T1_TOP - G) / 3)),
  grp([2], deskParts.svg),
  grp([2], bulbGlass(deskParts.bulb)),
  grp([2], pathLine(pathGround)),
  grp([2], flag(PIN_IDEA)),
  grp([2], flag(PIN_PVB)),
  // puntos terminales del camino en cada bandera
  ...(MOD === null
    ? [D([PIN_IDEA, PIN_PVB, PIN_PRD, PIN_UNITS, PIN_DEPLOY].map(at), { size: 2.6, tone: "hi" })]
    : [[2, [PIN_IDEA, PIN_PVB, PIN_PRD]], [4, [PIN_UNITS]], [8, [PIN_DEPLOY]]].map(([m, pts]) => grp([m], D(pts.map(at), { size: 2.6, tone: "hi" })))),
];

const milestones = [
  milestone("Idea", PIN_IDEA, 16, 4, "start", [2]),
  milestone("PVB", PIN_PVB, -10, 4, "end", [2]),
  milestone("PRD", PIN_PRD, -10, -2, "end", [2]),
  milestone("Unidades y tareas", PIN_UNITS, -10, -4, "end", [4]),
  milestone("Producción", PIN_DEPLOY, -8, -k.screenRise(20, P), "end", [8]),
];

// etiquetas de módulos (columna izquierda: lado +y; derecha: lado +x)
label("left", 0, "Módulo 5 · CKA", "administrar el clúster", [CP.x, CP.y + CP.d - 10, T3_TOP + CP_H], { mods: [5] });
label("left", 0, "Módulo 6 · CKAD", "desplegar aplicaciones", [W2.x + 8, W2.y + W2.d, T3_TOP + 10], { mods: [6] });
label("left", 0, "Módulo 4 · Kubernetes", "KCNA: el loop de reconciliación", [T3.x, T3.y + T3.d - 40, T3_TOP - 8], { mods: [4] });
label("left", 0, "Módulo 3 · Contenedores", "Docker, Compose, runtimes", [T2.x, T2.y + T2.d - 30, T2_TOP - 6], { mods: [3] });
label("left", 0, "Módulo 1 · Linux (LFCS)", "el suelo donde corre todo", [T1.x, T1.y + T1.d - 60, -8], { mods: [1] });
label("left", 0, "Módulo 2 · IA y especificaciones", "la idea, fijada en PVB y PRD", [DESK.x + 8, DESK.y + DESK.d, G + DESK_H - 1.5], { minY: 590, mods: [2] });
label("right", 0, "Módulo 8 · Agentes de IA", "proponen un PR; tú apruebas", [AGENT.x + AGENT.w, AGENT.y + 8, T3_TOP + 12], { mods: [8] });
label("right", 0, "Módulo 7 · Seguridad (CKS)", "asegurar el clúster", [6, -60, T3_TOP + 11], { mods: [7] });
label("right", 0, "Módulo 8 · GitOps y CI/CD", "del código a producción", [150, (BELT.y0 + BELT.y1) / 2, beltZ(150)], { mods: [8] });
label("right", 0, "Módulo 8 · IaC", "infraestructura como código", [GIT.x + GIT.w, GIT.y + 12, G + GIT_H - 10], { minY: 560, mods: [8] });
label("right", 0, "Módulo 9 · Helm", "opcional: charts y releases", [CRATE.x + CRATE.w, CRATE.y + CRATE.d / 2, G + 12], { muted: true, minY: 600, mods: [9] });

const MOD_CSS = `
.m-lo{opacity:.4}
.m-lo.m-txt{opacity:.62}
.m-hi .iso-top{fill:color-mix(in srgb,#2f6fe8 16%,var(--anatomy-top))}
.m-hi .iso-solid[data-lit]>.iso-top{fill:color-mix(in srgb,#2f6fe8 16%,var(--anatomy-lit-top))}
.m-hi .iso-shade[data-shade="0"]{fill:color-mix(in srgb,#2f6fe8 12%,var(--anatomy-shade-0))}
.m-hi .iso-shade[data-shade="1"]{fill:color-mix(in srgb,#2f6fe8 12%,var(--anatomy-shade-1))}
.m-hi .iso-shade[data-shade="2"]{fill:color-mix(in srgb,#2f6fe8 12%,var(--anatomy-shade-2))}
.m-hi .iso-shade[data-shade="3"]{fill:color-mix(in srgb,#2f6fe8 12%,var(--anatomy-shade-3))}
.m-hi{--anatomy-hi:#2f6fe8;--anatomy-mid:#2f6fe8;--anatomy-lo:#7aa2f0}
.m-hi .map-label{fill:#2f6fe8}
.m-hi .map-milestone{fill:#2f6fe8}
`;

const EXTRA_CSS = `
.map-bg{fill:var(--anatomy-card)}
.map-frame{fill:none;stroke:var(--anatomy-faint);stroke-width:1}
.map-title{fill:var(--anatomy-strong);font:700 26px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;letter-spacing:-.01em}
.map-subtitle{fill:var(--anatomy-text);font:400 15px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
.map-corner{fill:var(--anatomy-muted);font:500 11px var(--anatomy-mono);letter-spacing:.1em}
.map-label{fill:var(--anatomy-strong);font:650 15px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
.map-label.is-muted{fill:var(--anatomy-text)}
.map-sub{fill:var(--anatomy-text);font:400 13px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
.map-milestone{fill:var(--anatomy-lit);font:700 14px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif;paint-order:stroke;stroke:var(--anatomy-card);stroke-width:4px;stroke-linejoin:round}
.map-wire path{fill:none;stroke:var(--anatomy-mid);stroke-width:.8}
.map-wire circle{fill:var(--anatomy-card);stroke:var(--anatomy-hi);stroke-width:1}
.map-wire .map-wire-start{fill:var(--anatomy-mid);stroke:none}
.map-wire.is-muted path{stroke-dasharray:3 3}
.map-path{fill:none;stroke:var(--anatomy-lit);stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:.01 5.5}
.map-screen{fill:var(--anatomy-shade-0)}
.map-prompt{fill:var(--anatomy-hi);font-family:var(--anatomy-mono);font-weight:700}
.map-key path{fill:none;stroke-width:2.2;stroke-linecap:round}
.map-key text{fill:var(--anatomy-text);font:400 13px ui-sans-serif,system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
`;

function frame() {
  return [
    `<rect class="map-bg" x="0" y="0" width="${W}" height="${H}"/>`,
    `<rect class="map-frame" x="0.5" y="0.5" width="${W - 1}" height="${H - 1}"/>`,
    `<text class="map-title" x="32" y="58">${MOD === null ? "Mapa del curso" : `Estás aquí: Módulo ${MOD} · ${MOD_NAMES[MOD]}`}</text>`,
    `<text class="map-subtitle" x="32" y="84">Un solo proyecto tuyo sube capa por capa, de Linux a producción.</text>`,
    `<text class="map-corner" x="${W - 32}" y="40" text-anchor="end">TÓPICOS ESPECIALES · 9 MÓDULOS</text>`,
    `<g class="map-key"><path d="M32 ${H - 34}h40" style="stroke:var(--anatomy-lit);stroke-dasharray:.01 5.5"/><text x="82" y="${H - 29}">Tu proyecto: idea, PVB, PRD, unidades y tareas, producción</text></g>`,
    `<g class="map-key"><path d="M${W - 360} ${H - 34}h40" style="stroke:var(--anatomy-mid);stroke-width:.9;stroke-dasharray:3 3"/><text x="${W - 310}" y="${H - 29}">Módulo opcional, fuera del cronograma</text></g>`,
  ].join("");
}

const LABEL =
  "Mapa del curso como una torre isométrica de terrazas. Base: Módulo 1, Linux. Segunda terraza: Módulo 3, contenedores. Terraza superior: Módulo 4, Kubernetes, con el plano de control (Módulo 5, CKA), nodos con pods (Módulo 6, CKAD) y una valla de seguridad (Módulo 7, CKS). Una cinta transportadora desde un repositorio Git lleva commits al clúster y un agente de IA propone cambios (Módulo 8). Un escritorio con PVB y PRD representa el Módulo 2, y una caja de Helm el Módulo 9 opcional. Un camino de banderas sube por escaleras: idea, PVB, PRD, unidades y tareas, producción.";

for (const theme of ["light", "dark"]) {
  const svg = k
    .figureSvg({ width: W, height: H, label: MOD === null ? LABEL : `Módulo ${MOD} resaltado (${MOD_NAMES[MOD]}), el resto en segundo plano. ` + LABEL, standalone: theme, body: [frame(), ...art, ...milestones, labelsSvg()] })
    .replace("</style>", `${EXTRA_CSS}${MOD === null ? "" : MOD_CSS}</style>`)
    // en un <img> no hay animación ni scripts: quitamos las reglas que animan
    .replace(/@keyframes[^{]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}/g, "")
    .replace(/[^{}]*\{[^{}]*animation[^{}]*\}/g, "");
  const tn = theme === "light" ? "claro" : "oscuro";
  const name = MOD === null ? `mapa-del-curso-${tn}.svg` : `modulos/mapa-modulo-${MOD}-${tn}.svg`;
  if (MOD !== null) mkdirSync(join(OUT, "modulos"), { recursive: true });
  writeFileSync(join(OUT, name), svg);
  if (MOD === null && process.argv.includes("--html")) {
    writeFileSync(join(HERE, `vista-${theme === "light" ? "claro" : "oscuro"}.html`), `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#888"><div class="iso-plate" style="width:${W}px">${svg}</div></body>`);
  }
  console.log("escrito", name, (svg.length / 1024).toFixed(1), "KB");
}

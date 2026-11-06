const rueda = document.getElementById("rueda"), ctx = rueda.getContext("2d");
const COLORES = ["#e5484d", "#f5a524", "#30a46c", "#0091ff", "#8e4ec6",
                 "#e93d82", "#12a594", "#ff8b3e", "#5b6ee1", "#7ba52a"];
let angulo = 0;

function valores() {
  return document.getElementById("valores").value.split("\n").map(v => v.trim()).filter(Boolean);
}

function dibujar() {
  const v = valores(), n = Math.max(v.length, 1), a = 2 * Math.PI / n, c = 310;
  ctx.clearRect(0, 0, 620, 620);
  v.forEach((texto, i) => {
    ctx.beginPath(); ctx.moveTo(c, c);
    ctx.arc(c, c, 290, angulo + i * a, angulo + (i + 1) * a); ctx.closePath();
    ctx.fillStyle = COLORES[i % COLORES.length]; ctx.fill();
    ctx.strokeStyle = "#fff"; ctx.lineWidth = 3; ctx.stroke();
    const medio = angulo + (i + 0.5) * a, alReves = Math.cos(medio) < 0;
    ctx.save(); ctx.translate(c, c); ctx.rotate(medio + (alReves ? Math.PI : 0));
    ctx.fillStyle = "#fff"; ctx.font = "bold 28px system-ui";
    ctx.textAlign = alReves ? "left" : "right";   // en la mitad izquierda se voltea el texto
    ctx.fillText(texto.slice(0, 14), alReves ? -265 : 265, 10); ctx.restore();
  });
  ctx.beginPath(); ctx.moveTo(c - 20, 2); ctx.lineTo(c + 20, 2); ctx.lineTo(c, 46);
  ctx.fillStyle = "#ffd60a"; ctx.fill(); ctx.strokeStyle = "#333"; ctx.stroke();
}

function animar(indice, n, listo) {
  const a = 2 * Math.PI / n, destino = -Math.PI / 2 - (indice + 0.5) * a;
  const vueltas = 2 * Math.PI * 5 + ((destino - angulo) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
  const inicio = angulo, t0 = performance.now(), duracion = 3500;
  (function paso(t) {
    const k = Math.min((t - t0) / duracion, 1);
    angulo = inicio + vueltas * (1 - Math.pow(1 - k, 3));
    dibujar();
    k < 1 ? requestAnimationFrame(paso) : listo();
  })(t0);
}

document.getElementById("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const error = document.getElementById("error"), res = document.getElementById("resultado");
  error.textContent = ""; res.textContent = "";
  const r = await fetch("/api/girar", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ valores: valores() }),
  });
  const datos = await r.json();
  if (!r.ok) { error.textContent = datos.error; return; }
  animar(datos.indice, valores().length, () => { res.textContent = "Salió: " + datos.ganador; });
});
document.getElementById("valores").addEventListener("input", dibujar);
dibujar();

import os

from flask import Flask, jsonify, render_template, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, generate_latest

import ruleta

VERSION = os.environ.get("APP_VERSION", "dev")  # lo inyecta el Dockerfile al construir
app = Flask(__name__)

GIROS = Counter("ruleta_giros_total", "Giros de la ruleta", ["resultado"])
INFO = Gauge("ruleta_info", "Versión en ejecución", ["version"])
INFO.labels(version=VERSION).set(1)


@app.get("/")
def index():
    return render_template("index.html", version=VERSION)


@app.post("/api/girar")
def girar():
    valores = (request.get_json(silent=True) or {}).get("valores")
    try:
        indice, ganador = ruleta.girar(valores)
    except ValueError as error:
        GIROS.labels(resultado="rechazado").inc()
        return jsonify(error=str(error)), 400
    GIROS.labels(resultado="ok").inc()
    return jsonify(indice=indice, ganador=ganador, version=VERSION)


@app.get("/healthz")
def healthz():
    return jsonify(estado="ok", version=VERSION)


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

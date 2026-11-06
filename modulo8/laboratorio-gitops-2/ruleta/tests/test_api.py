import pytest

from app import app


@pytest.fixture
def cliente():
    return app.test_client()


def test_girar_ok(cliente):
    r = cliente.post("/api/girar", json={"valores": ["a", "b", "c"]})
    assert r.status_code == 200
    assert r.json["ganador"] in ["a", "b", "c"]


def test_girar_con_un_valor_da_400(cliente):
    r = cliente.post("/api/girar", json={"valores": ["a"]})
    assert r.status_code == 400
    assert "entre 2 y 10" in r.json["error"]


def test_girar_sin_cuerpo_da_400(cliente):
    assert cliente.post("/api/girar").status_code == 400


def test_healthz(cliente):
    assert cliente.get("/healthz").json["estado"] == "ok"


def test_metrics_cuenta_los_giros(cliente):
    cliente.post("/api/girar", json={"valores": ["a", "b"]})
    texto = cliente.get("/metrics").get_data(as_text=True)
    assert 'ruleta_giros_total{resultado="ok"}' in texto
    assert "ruleta_info{" in texto


def test_la_pagina_muestra_la_version(cliente):
    assert "Ruleta" in cliente.get("/").get_data(as_text=True)

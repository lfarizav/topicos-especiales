import random

import pytest

import ruleta


def test_dos_valores_es_el_minimo_valido():
    assert ruleta.validar(["a", "b"]) == ["a", "b"]


def test_diez_valores_es_el_maximo_valido():
    assert len(ruleta.validar([str(i) for i in range(10)])) == 10


@pytest.mark.parametrize("cantidad", [0, 1, 11, 50])
def test_fuera_de_rango_se_rechaza(cantidad):
    with pytest.raises(ValueError, match="entre 2 y 10"):
        ruleta.validar([str(i) for i in range(cantidad)])


@pytest.mark.parametrize("valores", [["a", ""], ["a", "   "], ["", ""]])
def test_en_blanco_se_rechaza(valores):
    with pytest.raises(ValueError, match="blanco"):
        ruleta.validar(valores)


def test_se_limpian_espacios_y_se_aceptan_numeros():
    assert ruleta.validar([" a ", 7]) == ["a", "7"]


def test_girar_devuelve_un_valor_de_la_lista():
    indice, valor = ruleta.girar(["a", "b", "c"], rng=random.Random(1))
    assert valor == ["a", "b", "c"][indice]

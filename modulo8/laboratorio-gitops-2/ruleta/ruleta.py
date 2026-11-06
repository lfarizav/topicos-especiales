"""Lógica pura de la ruleta: validar y elegir. No sabe nada de HTTP."""
import random

MIN_VALORES, MAX_VALORES = 2, 10


def validar(valores):
    """Devuelve los valores limpios o lanza ValueError."""
    if not isinstance(valores, list):
        raise ValueError("valores debe ser una lista")
    if not MIN_VALORES <= len(valores) <= MAX_VALORES:
        raise ValueError(f"se necesitan entre {MIN_VALORES} y {MAX_VALORES} valores")
    limpios = [str(v).strip() for v in valores]
    if not all(limpios):
        raise ValueError("no se permiten valores en blanco")
    return limpios


def girar(valores, rng=random):
    """Elige un índice al azar. Devuelve (índice, valor)."""
    limpios = validar(valores)
    indice = rng.randrange(len(limpios))
    return indice, limpios[indice]

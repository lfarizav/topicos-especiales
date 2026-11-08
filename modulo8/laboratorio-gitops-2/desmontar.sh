#!/bin/bash
# Borra solo lo que creo el montaje del Laboratorio 2 (Módulo 8).
W="$HOME/lab-gitops-2"
kind delete cluster --name gitops2 2>&1 | tail -1
docker rm -f gitops2-gitea gitops2-registry >/dev/null 2>&1
docker rmi localhost:5092/catalogo:1.0.0 localhost:5092/intruso:1.0.0 localhost:5092/ruleta:1.0.0 localhost:5092/ruleta:1.1.0 localhost:5092/ruleta:1.2.0 >/dev/null 2>&1
rm -rf "$W"; echo "TEARDOWN LISTO"

#!/bin/bash
# Borra solo lo que creo el montaje del laboratorio 1 del módulo 8.
W="$HOME/lab-gitops-1"
kind delete cluster --name m08-gitops1 --kubeconfig "$W/kubeconfig" 2>&1 | tail -1
docker rm -f gitops1-gitea gitops1-registry >/dev/null 2>&1
docker rmi localhost:5088/lab/hola:1.0.0 localhost:5088/lab/hola:respaldo localhost:5088/lab/intruso:1.0.0 >/dev/null 2>&1
rm -rf "$W"
echo "DESMONTAJE LISTO"

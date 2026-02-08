#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f ./argocd-install.yaml
sleep 5
kubectl apply -f ./root-app.yaml
#!/usr/bin/env bash
set -euo pipefail

kubectl apply -n argocd --server-side --force-conflicts -f ./argocd-install.yaml
sleep 5
kubectl apply -f ./root-app.yaml
sleep 20

kubectl apply -n argocd --server-side --force-conflicts -f ./secret/tls-secret.yaml
kubectl apply -n argocd --server-side --force-conflicts -f ./secret/db-user-secret.yaml
kubectl apply -n argocd --server-side --force-conflicts -f ./secret/openbao-postgres-secret.yaml
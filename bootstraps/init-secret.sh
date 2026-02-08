#!/usr/bin/env bash

set -euo pipefail
kubectl apply --server-side --force-conflicts -f ./secret/tls-secret.yaml
kubectl apply --server-side --force-conflicts -f ./secret/db-user-secret.yaml
kubectl apply --server-side --force-conflicts -f ./secret/openbao-postgres-secret.yaml

# Create a placeholder transit token secret (will be overwritten by the init container)
# This is needed so the StatefulSet can start - the init container will replace it
# with a real token obtained via Kubernetes auth
kubectl create namespace openbao --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic openbao-transit-token \
  --namespace=openbao \
  --from-literal=token="placeholder" \
  --dry-run=client -o yaml | kubectl apply --server-side --force-conflicts -f -
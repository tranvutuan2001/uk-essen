#!/usr/bin/env bash

set -euo pipefail
kubectl apply --server-side --force-conflicts -f ./secret/tls-secret.yaml
kubectl apply --server-side --force-conflicts -f ./secret/db-user-secret.yaml
kubectl apply --server-side --force-conflicts -f ./secret/openbao-postgres-secret.yaml
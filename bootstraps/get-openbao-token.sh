#!/bin/bash

set -e

NAMESPACE="openbao"
SECRET_NAME="openbao-init-credentials"

echo "Retrieving OpenBao root token..."

# Check if the secret exists
if ! kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
    echo "Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
    echo "Make sure OpenBao is initialized first."
    exit 1
fi

# Get the root token
ROOT_TOKEN=$(kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o jsonpath='{.data.root-token}' | base64 -d)

if [ -z "$ROOT_TOKEN" ]; then
    echo "Error: Could not retrieve root token from secret"
    exit 1
fi

echo ""
echo "OpenBao Root Token:"
echo "$ROOT_TOKEN"

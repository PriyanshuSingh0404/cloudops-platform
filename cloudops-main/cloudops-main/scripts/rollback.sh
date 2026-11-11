#!/bin/bash

set -e

SERVICE=${1:-"backend"}

if [[ "$SERVICE" != "backend" && "$SERVICE" != "frontend" ]]; then
  echo "Error: SERVICE must be 'backend' or 'frontend'"
  echo "Usage: bash scripts/rollback.sh [backend|frontend]"
  exit 1
fi

echo ">>> Rolling back deployment: $SERVICE"
echo ">>> Current revision history:"
kubectl rollout history deployment/$SERVICE

echo ""
echo ">>> Performing rollback..."
kubectl rollout undo deployment/$SERVICE

echo ">>> Waiting for rollback to complete..."
kubectl rollout status deployment/$SERVICE --timeout=120s

echo ""
echo ">>> Rollback complete. Current pod status:"
kubectl get pods | grep $SERVICE

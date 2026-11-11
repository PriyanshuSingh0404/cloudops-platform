#!/bin/bash

set -e

RESOURCE_GROUP="devops-intern-sandbox-rg-sandbox-sea"
AKS_NAME="cloudops-aks-dev"
ACR_NAME="cloudopsacrdev"

echo ">>> [1/5] Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --overwrite-existing

echo ">>> [2/5] Attaching ACR to AKS..."
az aks update \
  --name $AKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --attach-acr $ACR_NAME

echo ">>> [3/5] Deploying database..."
kubectl apply -f kubernetes/base/database/deployment.yml

echo ">>> [4/5] Waiting for database to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=db \
  --timeout=120s

echo ">>> [5/5] Deploying backend and frontend via pipeline..."
echo ">>> Triggering pipelines with empty commit..."
git commit --allow-empty -m "ci: trigger deployment pipelines"
git push origin main

echo ""
echo ">>> Deploy script complete!"
echo ">>> Monitor pods: kubectl get pods -w"
echo ">>> Get frontend IP: kubectl get service frontend-service"

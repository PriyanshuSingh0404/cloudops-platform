#!/bin/bash
# apply.sh - Provision infrastructure and deploy all applications
# Run this after a fresh clone or after terraform destroy
# Usage: bash scripts/apply.sh

set -e

RESOURCE_GROUP="devops-intern-sandbox-rg-sandbox-sea"
AKS_NAME="cloudops-aks-dev"
ACR_NAME="cloudopsacrdev"

echo "============================================"
echo " CloudOps Platform - Full Apply"
echo "============================================"

# Step 1: Terraform
echo ""
echo ">>> [1/6] Provisioning infrastructure with Terraform..."
cd terraform/environments/dev
terraform init
terraform apply -auto-approve \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="resource_group_name=$RESOURCE_GROUP" \
  -var="key_vault_name=$(az keyvault list --resource-group $RESOURCE_GROUP --query '[0].name' -o tsv)" \
  -var="address_space=10.1.0.0/16" \
  -var="address_prefix=10.1.0.0/22" \
  -var="service_cidr=10.2.0.0/16" \
  -var="dns_service_ip=10.2.0.10" \
  -var="project_name=cloudops" \
  -var="environment=dev"
cd ../../..

# Step 2: Kubeconfig
echo ""
echo ">>> [2/6] Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --overwrite-existing

# Step 3: ACR permission
echo ""
echo ">>> [3/6] Attaching ACR to AKS..."
az aks update \
  --name $AKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --attach-acr $ACR_NAME

# Step 4: Database
echo ""
echo ">>> [4/6] Deploying database..."
kubectl apply -f kubernetes/base/database/deployment.yml

echo ">>> Waiting for database to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=db \
  --timeout=120s

# Step 5: Trigger CI/CD for backend and frontend
echo ""
echo ">>> [5/6] Triggering CI/CD pipelines for backend and frontend..."
git commit --allow-empty -m "ci: trigger pipelines after infrastructure apply"
git push origin main

# Step 6: Status
echo ""
echo ">>> [6/6] Checking deployment status..."
echo ">>> Waiting 30 seconds for pipelines to start..."
sleep 30
kubectl get pods

echo ""
echo "============================================"
echo " Apply complete!"
echo " Monitor pipelines: https://github.com/szuryuu/cloudops/actions"
echo " Monitor pods:      kubectl get pods -w"
echo " Get frontend IP:   kubectl get service frontend-service"
echo "============================================"

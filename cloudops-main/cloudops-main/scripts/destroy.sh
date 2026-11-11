#!/bin/bash

set -e

RESOURCE_GROUP="devops-intern-sandbox-rg-sandbox-sea"
AKS_NAME="cloudops-aks-dev"

echo "============================================"
echo " CloudOps Platform - Full Destroy"
echo " WARNING: This will delete ALL resources"
echo "============================================"

# Confirmation
read -p "Are you sure you want to destroy everything? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Step 1: Get kubeconfig
echo ""
echo ">>> [1/5] Getting AKS credentials..."
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --overwrite-existing 2>/dev/null || echo ">>> AKS not found, skipping kubeconfig"

# Step 2: Delete Kubernetes resources
echo ""
echo ">>> [2/5] Deleting Kubernetes application resources..."
kubectl delete -f kubernetes/base/frontend/deployment.yml --ignore-not-found
kubectl delete -f kubernetes/base/backend/deployment.yml --ignore-not-found
kubectl delete -f kubernetes/base/database/deployment.yml --ignore-not-found

# Step 3: Delete monitoring namespace
echo ""
echo ">>> [3/5] Deleting monitoring namespace..."
kubectl delete namespace monitoring --ignore-not-found

# Step 4: Wait for pods to terminate
echo ""
echo ">>> [4/5] Waiting for all pods to terminate..."
kubectl wait --for=delete pod \
  -l "app in (frontend,backend,db)" \
  --timeout=120s 2>/dev/null || echo ">>> Pods already terminated or not found"

# Step 5: Terraform destroy
echo ""
echo ">>> [5/5] Destroying infrastructure with Terraform..."
cd terraform/environments/dev
terraform destroy -auto-approve \
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

echo ""
echo "============================================"
echo " Destroy complete!"
echo " All Azure resources have been removed."
echo " Run 'bash scripts/apply.sh' to recreate."
echo "============================================"

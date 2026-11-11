# Deployment Runbook

## Normal Deployment (via CI/CD Pipeline)

This is the standard workflow. No manual steps required.

```bash
# Make your changes
git add .
git commit -m "feat: your change description"
git push origin main
```

GitHub Actions automatically:

1. Builds and tests the code
2. Builds and pushes the Docker image to ACR
3. Applies the updated manifest to AKS
4. Waits for rollout to complete

Monitor the deployment:

```bash
# Watch GitHub Actions
# https://github.com/[USERNAME]/cloudops/actions

# Or watch pods directly
kubectl get pods -w
```

---

## Full Deployment from Scratch (after terraform destroy)

Run this after every `terraform apply`:

```bash
# Step 1: Provision infrastructure
cd terraform/environments/dev
terraform apply

# Step 2: Run the deploy script (handles kubeconfig + ACR attach + DB deploy)
cd ../../..
bash scripts/deploy.sh

# Step 3: Trigger pipelines to build and push images
git commit --allow-empty -m "ci: trigger pipelines after infra recreate"
git push origin main

# Step 4: Monitor
kubectl get pods -w
kubectl get service frontend-service
```

---

## Manual Deployment (if pipeline fails)

```bash
# Get kubeconfig
az aks get-credentials \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --name cloudops-aks-dev \
  --overwrite-existing

# Fix ACR permission if needed
az aks update \
  --name cloudops-aks-dev \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --attach-acr cloudopsacrdev

# Login to ACR and push image manually
az acr login --name cloudopsacrdev

cd applications/backend
docker build -t cloudopsacrdev.azurecr.io/backend:latest .
docker push cloudopsacrdev.azurecr.io/backend:latest

# Apply manifests
kubectl apply -f kubernetes/base/database/deployment.yml
kubectl apply -f kubernetes/base/backend/deployment.yml
kubectl apply -f kubernetes/base/frontend/deployment.yml

# Verify
kubectl get pods
kubectl get service frontend-service
```

---

## Cost Management

Destroy environment when not in use to preserve Azure credits:

```bash
# 1. Delete Kubernetes resources first (prevents VNet deletion errors)
kubectl delete -f kubernetes/base/frontend/deployment.yml
kubectl delete -f kubernetes/base/backend/deployment.yml
kubectl delete -f kubernetes/base/database/deployment.yml
kubectl delete namespace monitoring

# 2. Wait for all pods to terminate
kubectl get pods -w

# 3. Destroy infrastructure
cd terraform/environments/dev
terraform destroy
```

# Apply Runbook

## Overview

This runbook covers provisioning the full infrastructure from scratch
and deploying all applications to AKS.

Run this after: first-time setup, or after a `destroy`.

---

## Quick Apply (via Script)

```bash
bash scripts/apply.sh
```

The script handles all steps automatically:

1. `terraform apply` — provisions AKS, ACR, VNet
2. `az aks get-credentials` — configures kubectl
3. `az aks update --attach-acr` — grants AKS permission to pull from ACR
4. `kubectl apply` — deploys database
5. `git commit --allow-empty + push` — triggers CI/CD pipelines for backend and frontend

---

## Manual Apply (step by step)

Use this if the script fails at a specific step.

### Step 1: Provision Infrastructure

```bash
cd terraform/environments/dev

# First time only
terraform init

# Preview changes
terraform plan

# Apply
terraform apply
```

Wait for completion (~10-15 minutes for AKS).

### Step 2: Configure kubectl

```bash
az aks get-credentials \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --name cloudops-aks-dev \
  --overwrite-existing

# Verify cluster is accessible
kubectl get nodes
```

Expected output:

| Name                            | Status | Roles  | Age | Version | Notes             |
| ------------------------------- | ------ | ------ | --- | ------- | ----------------- |
| aks-default-xxxxxxxx-vmss000000 | Ready  | <none> | 5m  | v1.33.x | Newly provisioned |

### Step 3: Attach ACR to AKS

**This step is critical.** Without it, AKS cannot pull images from ACR.

```bash
az aks update \
  --name cloudops-aks-dev \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --attach-acr cloudopsacrdev
```

Verify the role assignment exists:

```bash
az role assignment list \
  --scope $(az acr show --name cloudopsacrdev --query id -o tsv) \
  --output table
```

The `Principal` in the output must match:

```bash
az aks show \
  --name cloudops-aks-dev \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --query identity.principalId -o tsv
```

### Step 4: Deploy Database

Database uses a public Docker Hub image, so it does not need a pipeline.

```bash
kubectl apply -f kubernetes/base/database/deployment.yml

# Wait until ready
kubectl wait --for=condition=ready pod -l app=db --timeout=120s
```

### Step 5: Trigger Pipelines

Backend and frontend images need to be built and pushed to ACR by the CI/CD pipelines.

```bash
git commit --allow-empty -m "ci: trigger pipelines after infrastructure apply"
git push origin main
```

Monitor pipelines at: `https://github.com/szuryuu/cloudops/actions`

### Step 6: Verify

```bash
# All 3 pods should be Running
kubectl get pods

# Get frontend external IP
kubectl get service frontend-service
```

Open `http://EXTERNAL_IP` in browser — GopherOps should load and tasks should be fetchable.

---

## Expected Timeline

| Step                | Duration           |
| ------------------- | ------------------ |
| terraform apply     | 10-15 minutes      |
| ACR attach          | 2-3 minutes        |
| Database ready      | 1-2 minutes        |
| Pipeline (backend)  | 3-5 minutes        |
| Pipeline (frontend) | 2-3 minutes        |
| **Total**           | **~20-25 minutes** |

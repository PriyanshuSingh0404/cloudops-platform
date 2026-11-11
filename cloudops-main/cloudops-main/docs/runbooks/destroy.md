# Destroy Runbook

## Overview

This runbook covers safely destroying all resources to preserve Azure credits.

**Always destroy when not actively working** — AKS costs money even when idle.

---

## Quick Destroy (via Script)

```bash
bash scripts/destroy.sh
```

The script handles the correct order automatically:

1. Deletes Kubernetes resources (releases Azure Load Balancer)
2. Deletes monitoring namespace
3. Waits for pod termination
4. Runs `terraform destroy`

---

## Manual Destroy (step by step)

Use this if the script fails.

### Step 1: Get kubeconfig

```bash
az aks get-credentials \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --name cloudops-aks-dev \
  --overwrite-existing
```

### Step 2: Delete Kubernetes resources

**This must be done before terraform destroy.**

If you skip this step, `terraform destroy` will fail because the Azure Load Balancer
created by the `frontend-service` (type: LoadBalancer) is attached to the VNet.
Terraform cannot delete the VNet while the Load Balancer still references it.

```bash
kubectl delete -f kubernetes/base/frontend/deployment.yml
kubectl delete -f kubernetes/base/backend/deployment.yml
kubectl delete -f kubernetes/base/database/deployment.yml
kubectl delete namespace monitoring --ignore-not-found
```

### Step 3: Wait for termination

```bash
kubectl get pods -w
# Wait until output is empty / "No resources found"
```

### Step 4: Terraform destroy

```bash
cd terraform/environments/dev
terraform destroy
```

Type `yes` when prompted. Wait 10-15 minutes.

### Step 5: Verify

Open `portal.azure.com` → Resource Groups → `devops-intern-sandbox-rg-sandbox-sea`

Confirm that `cloudops-aks-dev` and `cloudopsacrdev` no longer appear.

---

## Why Order Matters

| Step | Action            | Result                                      |
| ---- | ----------------- | ------------------------------------------- |
| 1    | terraform destroy | Fails: Load Balancer still attached to VNet |

### Correct Order

| Step | Action            | Result                    |
| ---- | ----------------- | ------------------------- |
| 1    | kubectl delete    | Releases Load Balancer    |
| 2    | terraform destroy | VNet deleted successfully |

---

## After Destroy

To bring everything back up:

```bash
bash scripts/apply.sh
```

Or follow the [Apply Runbook](apply.md).

# Troubleshooting Runbook

This document covers real issues encountered during development of this project.

---

## 1. ImagePullBackOff after terraform destroy + apply

**Symptom:**

| Name         | Ready | Status           | Restarts | Notes                         |
| ------------ | ----- | ---------------- | -------- | ----------------------------- |
| backend-xxx  | 0/1   | ImagePullBackOff | 0        | Failed to pull backend image  |
| frontend-xxx | 0/1   | ImagePullBackOff | 0        | Failed to pull frontend image |

**Root Cause:**
When AKS is destroyed and recreated, it gets a new SystemAssigned identity
with a different principal ID. The old ACR role assignment points to the
old identity, so the new AKS cannot pull images from ACR.

Additionally, ACR is empty after recreate — images must be re-pushed.

**Fix:**

```bash
# Step 1: Re-attach ACR to new AKS identity
az aks update \
  --name cloudops-aks-dev \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --attach-acr cloudopsacrdev

# Step 2: Trigger pipelines to re-push images
git commit --allow-empty -m "ci: re-trigger pipelines after infra recreate"
git push origin main

# Step 3: Monitor pods recovering
kubectl get pods -w
```

**Verify:**

```bash
az role assignment list \
  --scope $(az acr show --name cloudopsacrdev --query id -o tsv) \
  --output table

az aks show \
  --name cloudops-aks-dev \
  --resource-group devops-intern-sandbox-rg-sandbox-sea \
  --query identity.principalId -o tsv
```

Both principal IDs must match.

---

## 2. Pipeline timeout during rollout

**Symptom:**

```bash
Waiting for deployment "backend" rollout to finish: 1 old replicas are pending termination...
error: timed out waiting for the condition
```

**Root Cause:**
No readiness probe was defined. Kubernetes did not know when the new pod
was ready to serve traffic, so it kept waiting before terminating the old pod.

**Fix:**
Add readiness and liveness probes to the deployment manifest:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
livenessProbe:
  httpGet:
    path: /
    port: 5000
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3
```

---

## 3. Pipeline fails with "deployment not found"

**Symptom:**

```bash
Error from server (NotFound): deployments.apps "backend" not found
```

**Root Cause:**
The original pipeline used `kubectl set image`, which only works if the
deployment already exists in the cluster. After infra recreate, the
deployment does not exist yet.

**Fix:**
Use `kubectl apply -f` instead, which creates the deployment if it does
not exist, or updates it if it does:

```yaml
- name: Deploy to AKS
  run: |
    sed -i "s|cloudopsacrdev.azurecr.io/backend:latest|.../backend:${{ github.sha }}|g" \
      kubernetes/base/backend/deployment.yml
    kubectl apply -f kubernetes/base/backend/deployment.yml
    kubectl rollout status deployment/backend --timeout=300s
```

---

## 4. Nginx "host not found" for backend-service

**Symptom:**

```bash
[emerg] host not found in upstream "backend-service"
```

**Root Cause:**
`backend-service` is a Kubernetes service name that only resolves inside
the AKS cluster. In docker-compose, the service is named `backend` and
runs on port 5000.

**Fix:**
Two separate nginx config files:

- `nginx.conf` — for local development (uses `http://backend:5000/`)
- `nginx.k8s.conf` — for Kubernetes (uses `http://backend-service/`)

The Dockerfile uses `nginx.k8s.conf` for the production image.
docker-compose mounts `nginx.conf` instead.

---

## 5. CrashLoopBackOff — backend cannot connect to database

**Symptom:**

```bash
[error] failed to initialize database: hostname resolving error:
lookup db-service on 10.2.0.10:53: no such host
```

**Root Cause:**
Database pod was not deployed, or was deployed but not yet ready when
the backend started.

**Fix:**

```bash
# Check if database pod exists
kubectl get pods | grep db

# If not, deploy it
kubectl apply -f kubernetes/base/database/deployment.yml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=db --timeout=120s

# Restart backend
kubectl rollout restart deployment/backend
kubectl get pods -w
```

---

## 6. Frontend shows "CONNECTION_LOST" in browser

**Symptom:**
Browser shows the error panel: `CONNECTION_LOST // CHECK BACKEND`

**Diagnosis:**

```bash
# Test from inside the frontend pod
kubectl exec deployment/frontend -- wget -qO- http://backend-service/tasks
```

**Root Cause A — backend pod is not running:**

```bash
kubectl get pods | grep backend
kubectl logs deployment/backend
```

**Root Cause B — backend-service does not exist:**

```bash
kubectl get service backend-service
# If not found:
kubectl apply -f kubernetes/base/backend/deployment.yml
```

**Root Cause C — nginx proxy misconfiguration:**

```bash
kubectl exec deployment/frontend -- cat /etc/nginx/conf.d/default.conf
# Verify proxy_pass points to http://backend-service/
```

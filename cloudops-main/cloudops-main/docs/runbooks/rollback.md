# Rollback Runbook

## Rollback via Script

```bash
# Rollback backend
bash scripts/rollback.sh backend

# Rollback frontend
bash scripts/rollback.sh frontend
```

---

## Manual Rollback

```bash
# View deployment revision history
kubectl rollout history deployment/backend
kubectl rollout history deployment/frontend

# Rollback to previous version
kubectl rollout undo deployment/backend
kubectl rollout undo deployment/frontend

# Rollback to specific revision
kubectl rollout undo deployment/backend --to-revision=2

# Verify rollback completed
kubectl rollout status deployment/backend
kubectl get pods
```

---

## Verify After Rollback

```bash
# Check pods are running
kubectl get pods

# Test the API
FRONTEND_IP=$(kubectl get service frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$FRONTEND_IP/api/tasks

# Check logs
kubectl logs deployment/backend --tail=50
```

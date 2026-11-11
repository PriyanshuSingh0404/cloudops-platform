# CloudOps Platform — Project Specification

## Project Summary

A DevOps automation platform deployed on Azure Kubernetes Service demonstrating
end-to-end infrastructure provisioning, CI/CD automation, and observability.
Built as a portfolio project with a 17-day speedrun timeline.

This document reflects what was actually built, not an aspirational roadmap.
Known limitations are documented explicitly in their own section.

---

## What This Project Demonstrates

- Infrastructure as Code with Terraform (modular, remote state)
- Kubernetes deployment on AKS with health probes and service discovery
- CI/CD pipelines with GitHub Actions (path-triggered, image-tagged deploys)
- Container registry integration (ACR with managed identity)
- Monitoring stack deployment via Helm (Prometheus, Grafana, AlertManager)
- Operational runbooks based on real issues encountered during development
- Full lifecycle automation scripts (provision, deploy, rollback, backup, destroy)

---

## Tech Stack

| Layer          | Technology               | Version               |
| -------------- | ------------------------ | --------------------- |
| Cloud          | Microsoft Azure          |                       |
| Infrastructure | Terraform                | 1.9                   |
| Orchestration  | Kubernetes (AKS)         | 1.33                  |
| CI/CD          | GitHub Actions           |                       |
| Backend        | Go + Gin                 | 1.25                  |
| Database       | PostgreSQL               | 18                    |
| Frontend       | HTML + Nginx             | Alpine                |
| Monitoring     | Prometheus + Grafana     | kube-prometheus-stack |
| Registry       | Azure Container Registry | Basic                 |

---

## Architecture

### Request Flow

| Step | Layer         | Component             | Port | Notes         |
| ---- | ------------- | --------------------- | ---- | ------------- |
| 1    | Internet      |                       |      | Entry point   |
| 2    | Load Balancer | Azure Load Balancer   |      | Auto from K8s |
| 3    | Service       | frontend-service      | 80   | Public access |
| 4    | Pod           | Frontend (Nginx)      | 80   | Proxy /api/   |
| 5    | Service       | backend-service       | 80   | Internal only |
| 6    | Pod           | Backend (Go/Gin)      | 5000 | REST API      |
| 7    | Service       | db-service            | 5432 | Internal only |
| 8    | Pod           | Database (PostgreSQL) | 5432 | Storage       |

### Infrastructure

| Resource        | Value                 |
| --------------- | --------------------- |
| VNet CIDR       | 10.1.0.0/16           |
| Subnet CIDR     | 10.1.0.0/22           |
| Service CIDR    | 10.2.0.0/16           |
| AKS Node        | Standard_B2s (1 node) |
| ACR Tier        | Basic                 |
| Terraform State | Azure Blob Storage    |

### Key Design Decisions

**Nginx as reverse proxy**
The frontend does not call the backend via a public IP. All /api/\* requests
are proxied by Nginx to the Kubernetes internal service name backend-service.
Two nginx configs exist: nginx.conf for docker-compose (uses backend:5000)
and nginx.k8s.conf for Kubernetes (uses backend-service). The Dockerfile
uses nginx.k8s.conf for the production image.

**ClusterIP for backend and database**
Only the frontend requires a LoadBalancer. Backend and database use ClusterIP
and are not reachable from outside the cluster. This reduces attack surface
and Azure costs.

**SystemAssigned identity for AKS**
AKS uses a SystemAssigned managed identity to pull images from ACR.
No credentials are stored anywhere. The identity is granted AcrPull
via Terraform azurerm_role_assignment.

Known issue: when AKS is destroyed and recreated, it gets a new principal ID.
The old role assignment becomes stale. Fix requires running
az aks update --attach-acr cloudopsacrdev after every infra recreate.

---

## Project Structure

```
cloudops-platform/
├── .github/workflows/
│   ├── backend-pipeline.yml
│   ├── frontend-pipeline.yml
│   └── infrastructure-pipeline.yml
├── applications/
│   ├── backend/             # Go/Gin REST API
│   ├── frontend/            # HTML + Nginx
│   └── docker-compose.yml
├── kubernetes/base/
│   ├── backend/deployment.yml
│   ├── frontend/deployment.yml
│   └── database/deployment.yml
├── terraform/
│   ├── environments/dev/
│   └── modules/
│       ├── kubernetes/
│       └── networking/
├── monitoring/
│   └── alerting/rules.yml
├── scripts/
│   ├── apply.sh
│   ├── destroy.sh
│   ├── deploy.sh
│   ├── rollback.sh
│   └── backup.sh
├── docs/
│   ├── architecture.md
│   └── runbooks/
│       ├── apply.md
│       ├── destroy.md
│       ├── deployment.md
│       ├── rollback.md
│       └── troubleshooting.md
├── Makefile
└── README.md
```

---

## CI/CD Pipelines

Every push to main triggers the relevant pipeline based on file path.

| Changed Path               | Pipeline       | Steps                                              |
| -------------------------- | -------------- | -------------------------------------------------- |
| applications/backend/\*\*  | Backend CI/CD  | go build → docker build → push ACR → kubectl apply |
| applications/frontend/\*\* | Frontend CI/CD | docker build → push ACR → kubectl apply            |
| terraform/\*\*             | Infrastructure | fmt check → validate → plan (no auto apply)        |

All pipelines use kubectl apply -f instead of kubectl set image.
This ensures deployments succeed even after infra recreate when
the deployment resource does not yet exist in the cluster.

---

## API Reference

| Method | Endpoint   | Description    |
| ------ | ---------- | -------------- |
| GET    | /          | Health check   |
| GET    | /tasks     | List all tasks |
| POST   | /tasks     | Create a task  |
| GET    | /tasks/:id | Get task by ID |
| PUT    | /tasks/:id | Update task    |
| DELETE | /tasks/:id | Delete task    |
| GET    | /users     | List all users |
| POST   | /users     | Create a user  |
| GET    | /users/:id | Get user by ID |
| PUT    | /users/:id | Update user    |
| DELETE | /users/:id | Delete user    |

---

## Monitoring Stack

Deployed via Helm (kube-prometheus-stack).

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin123
```

Components deployed:

- Prometheus — scrapes metrics from pods and nodes
- Grafana — visualizes metrics via built-in Kubernetes dashboards
- AlertManager — routes alerts based on rules in monitoring/alerting/rules.yml
- Node Exporter — node-level metrics (CPU, memory, disk)
- kube-state-metrics — Kubernetes object state as metrics

Access Grafana:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# http://localhost:3000 — admin / admin123
```

Alert rule groups implemented: pod-alerts, resource-alerts, service-alerts.

---

## Operational Scripts

| Script      | Usage                            | Description                                |
| ----------- | -------------------------------- | ------------------------------------------ |
| apply.sh    | bash scripts/apply.sh            | Full provision from scratch                |
| destroy.sh  | bash scripts/destroy.sh          | Safe teardown in correct order             |
| deploy.sh   | bash scripts/deploy.sh           | Post-infra deploy (kubeconfig + ACR + DB)  |
| rollback.sh | bash scripts/rollback.sh backend | Rollback a deployment to previous revision |
| backup.sh   | bash scripts/backup.sh           | pg_dump from AKS pod to ./backups/         |

Makefile targets: up, down, deploy, rollback, backup, monitoring-up, tf-plan, tf-apply, tf-destroy.

---

## Known Limitations

These are acknowledged gaps, not overlooked items.

| Area               | Limitation                                                        |
| ------------------ | ----------------------------------------------------------------- |
| Testing            | No unit or integration tests in the application codebase          |
| Security scanning  | No Trivy or container image scanning in CI/CD pipelines           |
| Secrets management | Database credentials hardcoded in Kubernetes manifests            |
| Log aggregation    | No Loki or ELK — metrics only, no centralized log storage         |
| Helm               | Raw Kubernetes manifests only, no Helm chart packaging            |
| Multi-environment  | Single DEV environment only — no staging or prod                  |
| Auto-scaling       | No HPA configured — single replica per deployment                 |
| TLS                | No HTTPS — HTTP only on the frontend LoadBalancer                 |
| Identity issue     | ACR-AKS role assignment breaks on every terraform destroy + apply |

---

## Real Issues Encountered and Resolved

This section documents actual problems hit during development.
Each entry has a root cause and a fix that was verified to work.

1. ImagePullBackOff after terraform destroy + apply
   Root cause: AKS gets new principal ID on recreate. Old role assignment becomes stale.
   Fix: az aks update --attach-acr cloudopsacrdev after every infra recreate.

2. Pipeline timeout during rollout
   Root cause: No readiness probe. K8s did not know when pod was ready.
   Fix: Added readinessProbe and livenessProbe to backend deployment manifest.

3. Pipeline fails with "deployment not found"
   Root cause: kubectl set image requires deployment to already exist.
   Fix: Switched to kubectl apply -f which creates or updates.

4. Nginx "host not found" for backend-service
   Root cause: backend-service only resolves inside AKS cluster, not in docker-compose.
   Fix: Separate nginx configs — nginx.conf for docker-compose, nginx.k8s.conf for K8s.

5. CrashLoopBackOff — backend cannot connect to database
   Root cause: Database pod not deployed, or not yet ready when backend started.
   Fix: Deploy database first, wait for readiness, then trigger backend pipeline.

6. Frontend shows CONNECTION_LOST in browser
   Root cause: backend pod down, backend-service missing, or nginx misconfiguration.
   Fix: Diagnose in order — check pods, check service, check nginx config.

---

## Quick Start (Local Development)

Prerequisites: Docker, Docker Compose

```bash
git clone https://github.com/szuryuu/cloudops.git
cd cloudops

cd applications
docker-compose up --build

# Frontend: http://localhost
# Backend:  http://localhost/api/tasks
```

## Infrastructure Setup

Prerequisites: Terraform 1.9+, Azure CLI, kubectl

```bash
az login
bash scripts/apply.sh
```

Or step by step:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Fill in: subscription_id, resource_group_name, key_vault_name
terraform init
terraform apply

cd ../../..
bash scripts/deploy.sh
```

---

## Runbooks

- [Apply — full provision from scratch](docs/runbooks/apply.md)
- [Destroy — safe teardown](docs/runbooks/destroy.md)
- [Deployment — normal and manual deploy](docs/runbooks/deployment.md)
- [Rollback](docs/runbooks/rollback.md)
- [Troubleshooting — real issues and fixes](docs/runbooks/troubleshooting.md)

---

## GitHub Secrets Required

| Secret                | Description                     |
| --------------------- | ------------------------------- |
| AZURE_CLIENT_ID       | Service principal client ID     |
| AZURE_CLIENT_SECRET   | Service principal client secret |
| AZURE_SUBSCRIPTION_ID | Azure subscription ID           |
| AZURE_TENANT_ID       | Azure tenant ID                 |
| ACR_LOGIN_SERVER      | e.g. cloudopsacrdev.azurecr.io  |
| RESOURCE_GROUP        | Azure resource group name       |
| AKS_CLUSTER_NAME      | AKS cluster name                |
| KEY_VAULT_NAME        | Azure Key Vault name            |

---

## Interview Talking Points

Opening: "I built a production-grade DevOps platform on AKS that automates the full
infrastructure lifecycle — from provisioning with Terraform to deploying via GitHub Actions
to monitoring with Prometheus and Grafana."

Questions to prepare for:

- Walk me through what happens when you push code to main
- Why did you use SystemAssigned identity instead of UserAssigned?
- How does the nginx reverse proxy work in your setup?
- Why does kubectl apply work but kubectl set image fails after recreate?
- What would you do differently if you rebuilt this?
- How do you ensure the database is ready before the backend starts?
- What does the destroy order matter?
- What are the security weaknesses in your current setup?

---

## Planned Improvements

If this project continues beyond MVP:

- Add Trivy container scanning step to CI/CD pipelines
- Move database credentials to Azure Key Vault and mount as K8s secrets
- Add HPA for backend deployment based on CPU metrics
- Add Loki for log aggregation
- Write unit tests for Go backend controllers
- Add HTTPS via cert-manager and Let's Encrypt
- Fix the ACR identity issue with UserAssigned identity instead of SystemAssigned

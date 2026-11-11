# Architecture Documentation

## System Overview

CloudOps Platform is a 3-tier application running on Azure Kubernetes Service.
Each layer is isolated and communicates through Kubernetes internal DNS,
following the same patterns used in production-grade systems.

## Request Flow

| Step | Layer         | Component             | Port | Notes          |
| ---- | ------------- | --------------------- | ---- | -------------- |
| 1    | Internet      | -                     | -    | Entry point    |
| 2    | Load Balancer | Azure Load Balancer   | -    | Auto from K8s  |
| 3    | Service       | frontend-service      | 80   | Public access  |
| 4    | Pod           | Frontend (Nginx)      | 80   | Proxy `/api/*` |
| 5    | Service       | backend-service       | 80   | Internal       |
| 6    | Pod           | Backend (Go/Gin)      | 5000 | API            |
| 7    | Service       | db-service            | 5432 | Internal       |
| 8    | Pod           | Database (PostgreSQL) | 5432 | Storage        |

## Key Design Decisions

### Nginx as Reverse Proxy

The frontend does not call the backend directly via a public IP.
All requests to `/api/*` are proxied by Nginx to `backend-service` —
the Kubernetes service name that always resolves correctly regardless
of what IP the pod is assigned.

This eliminates hardcoded IPs and follows the correct production pattern.
Two separate nginx configs exist:

- `nginx.conf` — for local docker-compose (uses `backend:5000`)
- `nginx.k8s.conf` — for Kubernetes (uses `backend-service`)

### ClusterIP for Backend and Database

Backend and database do not need external IPs.
Only the frontend requires a LoadBalancer.
This reduces the attack surface and Azure costs.

### SystemAssigned Identity for AKS

AKS uses a SystemAssigned managed identity to pull images from ACR.
This avoids storing credentials anywhere.
The identity is granted `AcrPull` role via Terraform `azurerm_role_assignment`.

**Known Issue:** When AKS is destroyed and recreated, it gets a new identity.
The Terraform role assignment may not propagate immediately.
Fix: run `az aks update --attach-acr cloudopsacrdev` after recreating.

## CI/CD Flow

```bash
git push main
│
├── applications/backend/** changed
│   │
│   ├── go build ./...              (compile check)
│   ├── docker build & push        (ACR)
│   └── kubectl apply -f           (AKS deployment)
│
├── applications/frontend/** changed
│   │
│   ├── docker build & push        (ACR)
│   └── kubectl apply -f           (AKS deployment)
│
└── terraform/** changed
    │
    ├── terraform fmt --check
    ├── terraform validate
    └── terraform plan             (no auto apply)
```

## Infrastructure

| Resource        | Value                 |
| --------------- | --------------------- |
| VNet CIDR       | 10.1.0.0/16           |
| Subnet CIDR     | 10.1.0.0/22           |
| Service CIDR    | 10.2.0.0/16           |
| AKS Node        | Standard_B2s (1 node) |
| ACR Tier        | Basic                 |
| Terraform State | Azure Blob Storage    |

## Monitoring Stack

Deployed via Helm (`kube-prometheus-stack`):

- **Prometheus** — scrapes metrics from all pods and nodes
- **Grafana** — visualizes metrics via pre-built Kubernetes dashboards
- **AlertManager** — routes alerts based on rules in `monitoring/alerting/rules.yml`
- **Node Exporter** — collects node-level metrics (CPU, memory, disk)
- **kube-state-metrics** — exposes Kubernetes object state as metrics

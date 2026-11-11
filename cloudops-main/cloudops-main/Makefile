.PHONY: up down deploy rollback backup monitoring-up

# ─── Local Development ───────────────────────────────────────────

## Start all services locally with docker-compose
up:
	cd applications && docker-compose up --build

## Stop all local services
down:
	cd applications && docker-compose down

# ─── Kubernetes Operations ────────────────────────────────────────

## Full deployment after terraform apply
deploy:
	bash scripts/deploy.sh

## Rollback a deployment. Usage: make rollback SERVICE=backend
rollback:
	bash scripts/rollback.sh $(SERVICE)

## Backup PostgreSQL from AKS pod
backup:
	bash scripts/backup.sh

## Access Grafana dashboard via port-forward
monitoring-up:
	kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# ─── Terraform ───────────────────────────────────────────────────

## Preview infrastructure changes
tf-plan:
	cd terraform/environments/dev && terraform plan

## Apply infrastructure changes
tf-apply:
	cd terraform/environments/dev && terraform apply

## Destroy all infrastructure (run kubectl delete first!)
tf-destroy:
	cd terraform/environments/dev && terraform destroy

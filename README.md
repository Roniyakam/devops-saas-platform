# devops-saas-platform

Plateforme SaaS distribuée déployée en GitOps sur Kubernetes (K3s).
Projet de portfolio DevOps — Semaine 1/4 terminée.

## Stack technique

| Composant | Technologie |
|---|---|
| IaC / Automation | Ansible (AWX en prod) |
| Container orchestration | K3s (Kubernetes) |
| GitOps | ArgoCD |
| Package management | Helm |
| Secrets | HashiCorp Vault |
| Database HA | PostgreSQL + Patroni + HAProxy + PgBouncer |
| Async tasks | Celery + RabbitMQ |
| Observability | Prometheus + Loki + Grafana |
| Cloud | Scaleway (fr-par-1) |

## Infrastructure

5 instances Scaleway :

```
vm-infra       DEV1-S   Ansible control node
vm-k8s-master  DEV1-L   K3s control-plane + ArgoCD + Vault
vm-k8s-worker  DEV1-L   K3s worker (apps + Celery workers)
vm-postgres    DEV1-S   Patroni + HAProxy + PgBouncer
vm-monitoring  DEV1-M   Prometheus + Loki + Grafana
```

## Démarrage rapide

```bash
# 1. Configurer l'inventaire
cp ansible/inventories/scaleway/hosts.ini.example ansible/inventories/scaleway/hosts.ini
# Éditer hosts.ini avec les IPs Scaleway réelles
# hosts.ini est dans .gitignore : jamais commité (IPs réelles)

# 2. Déployer le socle commun
cd ansible
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/site.yml -u root

# 3. Déployer le cluster K3s
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/deploy-k8s.yml -u root

# 4. Accéder au cluster
export KUBECONFIG=./fetched/vm-k8s-master-k3s.yaml
kubectl get nodes
```

## Décisions d'architecture

- [ADR 001 — Environnement Scaleway](docs/adr/001-scaleway-environment.md)
- [ADR 002 — Dimensionnement des instances](docs/adr/002-instance-sizing.md)

## Avancement

- [x] **S1** — Fondations Git + Ansible + Kubernetes
  - Structure Ansible production-grade (rôles préfixés, ansible-lint profil production)
  - Rôle `common` : packages, timezone, UFW, sysctl, modules kernel
  - Rôle `k8s_common` : prérequis cluster (swap, br_netfilter)
  - Rôle `k8s_master` : K3s control-plane + ArgoCD bootstrap
  - Rôle `k8s_worker` : jonction au cluster
  - Idempotence validée (changed=0 au 2e run)
- [ ] **S2** — GitOps + Vault + Celery + RabbitMQ
- [ ] **S3** — PostgreSQL HA + Observabilité
- [ ] **S4** — Publication GitHub/LinkedIn

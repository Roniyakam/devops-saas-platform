# devops-saas-platform

![CI](https://github.com/Roniyakam/devops-saas-platform/workflows/CI/badge.svg)

> Plateforme SaaS distribuée déployée en mode GitOps sur Kubernetes (K3s).
> Projet de portfolio DevSecOps — Infrastructure as Code, GitOps, Secret Management,
> Observabilité, PostgreSQL HA.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SCALEWAY fr-par-1                         │
│                                                              │
│  ┌──────────┐    ┌─────────────────────────────────────┐    │
│  │ vm-infra │    │         K3s Cluster                 │    │
│  │ DEV1-S   │───▶│  ┌──────────────┐ ┌─────────────┐  │    │
│  │ Ansible  │    │  │ vm-k8s-master│ │vm-k8s-worker│  │    │
│  │ Control  │    │  │ DEV1-L       │ │DEV1-L       │  │    │
│  │ Node     │    │  │ ArgoCD       │ │Celery       │  │    │
│  └──────────┘    │  │ Vault (Raft) │ │Workers      │  │    │
│                  │  │ RabbitMQ     │ │             │  │    │
│  ┌──────────┐    │  └──────────────┘ └─────────────┘  │    │
│  │vm-postgres    └─────────────────────────────────────┘    │
│  │ DEV1-S   │                                               │
│  │ Patroni  │    ┌──────────────────────────────────────┐   │
│  │ HAProxy  │    │ vm-monitoring  DEV1-M                │   │
│  │ PgBouncer│    │ Prometheus + Loki + Grafana          │   │
│  └──────────┘    └──────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   GitHub           │
                    │ Source of Truth    │
                    │ ArgoCD watches     │
                    │ CI/CD pipeline     │
                    └────────────────────┘
```

## Stack technique

| Couche | Technologie | Version | Rôle |
|--------|------------|---------|------|
| IaC | Ansible | 2.16 | Automatisation infrastructure |
| Container | K3s | v1.29.4 | Kubernetes léger |
| GitOps | ArgoCD | v2.10.4 | Déploiement déclaratif |
| Secrets | HashiCorp Vault | 1.17.2 | Gestion centralisée secrets |
| Messaging | RabbitMQ | 3.x | Broker de messages |
| Async | Celery | 5.4.0 | Workers asynchrones |
| Database | PostgreSQL | 16 | Base de données |
| HA | Patroni | 3.3.2 | Leader election automatique |
| Proxy | HAProxy | 2.8 | Load balancing TCP |
| Pool | PgBouncer | 1.22 | Connection pooling |
| Metrics | Prometheus | v2.53.0 | Collecte métriques |
| Logs | Loki | 3.0.0 | Agrégation logs |
| Viz | Grafana | 11.1.0 | Dashboards |
| Cloud | Scaleway | fr-par-1 | Infrastructure cloud |

## Infrastructure (5 VM Scaleway)

| VM | Type | Rôle |
|----|------|------|
| vm-infra | DEV1-S | Ansible control node |
| vm-k8s-master | DEV1-L | K3s control-plane + ArgoCD + Vault |
| vm-k8s-worker | DEV1-L | K3s worker (Celery workers) |
| vm-postgres | DEV1-S | PostgreSQL HA (Patroni + HAProxy + PgBouncer) |
| vm-monitoring | DEV1-M | Prometheus + Loki + Grafana |

## Principes DevSecOps appliqués

- **Security by Design** : UFW sur toutes les VMs, least-privilege RBAC Vault
- **Zero Trust** : aucun secret en clair dans Git, injection via Vault Agent
- **GitOps pur** : tout changement = commit Git + sync ArgoCD automatique
- **Idempotence** : `changed=0` au 2e run Ansible (gate CI obligatoire)
- **Supply chain** : actions SHA-pinnées, gitleaks sur tout l'historique
- **Observabilité** : métriques + logs + alertes (3 alertes critiques configurées)
- **Incident management** : post-mortem documenté (docs/incidents/)
- **ADR** : Architecture Decision Records pour chaque choix technique

## Démarrage rapide

### Prérequis
- 5 VM Scaleway Ubuntu 24.04 LTS (voir docs/adr/002-instance-sizing.md)
- Ansible >= 2.16 sur vm-infra
- kubectl installé sur vm-infra
- Fichier vault password : `~/.vault_pass`

### Déploiement

```bash
# 1. Cloner le repo sur vm-infra
git clone https://github.com/Roniyakam/devops-saas-platform.git
cd devops-saas-platform

# 2. Configurer l'inventaire
cp ansible/inventories/scaleway/hosts.ini.example \
   ansible/inventories/scaleway/hosts.ini
# Éditer avec les vraies IPs Scaleway

# 3. Déployer le socle commun
cd ansible
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/site.yml

# 4. Déployer K3s + ArgoCD
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/deploy-k8s.yml

# 5. Déployer Vault
ansible-playbook -i inventories/scaleway/hosts.ini \
  playbooks/deploy-vault.yml --vault-password-file ~/.vault_pass

# 6. Déployer les applications GitOps
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/deploy-gitops.yml

# 7. Déployer PostgreSQL HA
ansible-playbook -i inventories/scaleway/hosts.ini \
  playbooks/deploy-postgres.yml --vault-password-file ~/.vault_pass

# 8. Déployer l'observabilité
ansible-playbook -i inventories/scaleway/hosts.ini \
  playbooks/deploy-monitoring.yml --vault-password-file ~/.vault_pass
```

## Accès aux interfaces (via SSH tunnel)

```bash
# Grafana (métriques et dashboards)
ssh -L 3000:localhost:3000 root@VM_MONITORING_IP -N
# → http://localhost:3000

# Prometheus (alertes)
ssh -L 9090:localhost:9090 root@VM_MONITORING_IP -N
# → http://localhost:9090

# ArgoCD (GitOps)
kubectl port-forward svc/argocd-server -n argocd 8080:443
ssh -L 9080:localhost:8080 root@VM_INFRA_IP -N
# → https://localhost:9080

# HAProxy stats (PostgreSQL HA)
ssh -L 5000:localhost:5000 root@VM_POSTGRES_IP -N
# → http://localhost:5000

# Flower (Celery workers)
kubectl port-forward svc/celery-flower -n celery 5555:5555
ssh -L 15555:localhost:5555 root@VM_INFRA_IP -N
# → http://localhost:15555
```

## Sécurité

- Vault Raft storage (persistent, survit aux redémarrages)
- Vault Agent Injector (secrets montés en mémoire, jamais en env vars)
- UFW actif sur toutes les VMs (default deny, allow explicite)
- IPs non commitées dans Git (hosts.ini gitignorée)
- Gitleaks scan sur tout l'historique (CI)
- SHA pinning sur toutes les GitHub Actions
- no_log: true sur toutes les tâches sensibles Ansible
- Commits signés par Roniyakam uniquement

## CI/CD

Pipeline GitHub Actions déclenché sur chaque push :
1. `ansible-lint` (profil production, 0 violation tolérée)
2. `yamllint` (config adaptée Ansible)
3. `gitleaks` (scan secrets sur tout l'historique git)
4. Security gate (bloque le merge si une gate échoue)

## Documentation

- [Architecture Decision Records](docs/adr/)
- [Incidents & Post-mortems](docs/incidents/)
- [Security Rules](docs/security-rules.md)
- [CI Limitations & Trade-offs](docs/ci-limitations.md)
- [Known Issues](docs/known-issues.md)

## Semaines d'exécution

- [x] **S1** — Fondations : Ansible + K3s + CI
- [x] **S2** — GitOps : ArgoCD + Vault + RabbitMQ + Celery
- [x] **S3** — Data & Observabilité : PostgreSQL HA + Prometheus + Grafana
- [ ] **S4** — Publication : README final + LinkedIn *(en cours)*

---
*Projet portfolio DevSecOps — Roni YAKAM*

# ADR 002 — Dimensionnement des instances Scaleway

**Date** : Juin 2026  
**Statut** : Accepté  
**Décideurs** : Roni (DevOps Engineer)

## Contexte

Le projet nécessite 5 instances Scaleway. Trois profils de dimensionnement ont été évalués :
- **Minimal** : tout en DEV1-S (2 vCPU / 2 GB) — risque d'OOM sur master et worker
- **Intermédiaire** : sizing différencié selon les rôles — compromis coût/performance
- **Confortable** : tout en DEV1-L ou DEV1-M — coût élevé, peu justifié

## Décision

**Sizing intermédiaire différencié** :

| Instance | Type | vCPU | RAM | Rôle |
|---|---|---|---|---|
| vm-k8s-master | DEV1-L | 4 | 8 GB | K3s control-plane + ArgoCD + Vault |
| vm-k8s-worker | DEV1-L | 4 | 8 GB | K3s worker (apps + Celery workers) |
| vm-monitoring | DEV1-M | 3 | 4 GB | Prometheus + Loki + Grafana |
| vm-infra | DEV1-S | 2 | 2 GB | Ansible control node |
| vm-postgres | DEV1-S | 2 | 2 GB | Patroni + HAProxy + PgBouncer |

## Justification

- **Master et worker en DEV1-L** : ArgoCD + Vault + apps applicatives consomment facilement 4-6 GB RAM
- **Monitoring en DEV1-M** : Prometheus a besoin de 2-3 GB RAM, Loki + Grafana ~1 GB de plus
- **Infra et Postgres en DEV1-S** : Ansible control node est léger ; PostgreSQL standalone en DEV1-S est suffisant pour un projet de portfolio

## Conséquences

- Coût full-time : ~90€/mois
- Coût réel (stop/start entre sessions) : ~22-26€/semaine

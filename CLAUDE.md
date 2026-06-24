# devops-saas-platform — CLAUDE.md

## Contexte du projet

Plateforme SaaS distribuée déployée en GitOps sur Kubernetes (K3s).
Projet de portfolio pour entretien technique DevOps (Patrowl.io).

Infrastructure : 5 instances Scaleway zone fr-par-1
- vm-infra       : DEV1-S — Ansible control node
- vm-k8s-master  : DEV1-L — K3s control-plane + ArgoCD + Vault
- vm-k8s-worker  : DEV1-L — K3s worker (apps + Celery worker)
- vm-postgres    : DEV1-S — Patroni + HAProxy + PgBouncer
- vm-monitoring  : DEV1-M — Prometheus + Loki + Grafana

Décisions d'architecture : docs/adr/001-scaleway-environment.md
                            docs/adr/002-instance-sizing.md

## Commandes essentielles

```bash
# Socle commun (toutes les instances)
cd ansible
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/site.yml -u root

# Déploiement cluster K3s (3 plays ordonnés : k8s_common → k8s_master → k8s_worker)
ansible-playbook -i inventories/scaleway/hosts.ini playbooks/deploy-k8s.yml

# Vérifier l'idempotence (changed=0 attendu au 2e run)
./scripts/check-idempotence.sh inventories/scaleway/hosts.ini playbooks/site.yml

# Lint Ansible — profil production, 0 failure toléré
cd ansible && ansible-lint -f pep8 playbooks/site.yml playbooks/deploy-k8s.yml

# Accès cluster après déploiement
export KUBECONFIG=./ansible/fetched/vm-k8s-master-k3s.yaml
kubectl get nodes
```

## Règles non négociables

1. **IDEMPOTENCE STRICTE** : changed=0 au 2e run est une gate, pas une option.
   Toujours vérifier avec check-idempotence.sh avant tout commit.

2. **GITOPS PUR** : aucun kubectl apply/delete manuel hors bootstrap initial.
   Tout changement = commit Git + sync ArgoCD. Voir docs/gitops-workflow.md.

3. **NOMMAGE VARIABLES ANSIBLE** : préfixe obligatoire par rôle (common_*,
   k8s_master_*, k8s_worker_*, k8s_common_*). Exception documentée :
   k3s_version reste sans préfixe (variable de domaine partagée entre
   k8s_master et k8s_worker — voir ansible/.ansible-lint).

4. **ORDRE UFW CRITIQUE** : règles allow (SSH + réseau privé) TOUJOURS avant
   state: enabled. Inversion = coupure connexion Ansible, hôte injoignable.

5. **PAS DE `latest`** : toute version (K3s, Helm charts, images) est pinnée.

6. **SECRETS** : ansible-vault pour Ansible, Vault pour Kubernetes — stockage
   Raft uniquement, jamais inmem en production (voir docs/architecture.md).
   Jamais en clair dans Git. Voir vault.yml.example. Ne jamais commiter
   `fetched/`, `vault-init.yml`, `vault-secrets.yml`, `hosts.ini` (IPs
   réelles — éditer depuis `hosts.ini.example`, gitignored).

7. **NAMESPACE OWNERSHIP** : un namespace K8s = un owner (Ansible/Helm OU
   ArgoCD, jamais les deux) — voir docs/incidents/.

8. **CI GATES** : ansible-lint + gitleaks doivent passer avant tout merge
   (voir .github/workflows/ci.yml).

Détail complet : bugs connus → docs/known-issues.md · règles de sécurité →
docs/security-rules.md · incidents → docs/incidents/.

## Incidents et leçons apprises

- Règle 001 — namespace ownership : ArgoCD prune=true supprime tout ce
  qu'il ne connaît pas ; désinstaller Ansible avant d'activer ArgoCD sync
  (incident 001 : docs/incidents/001-argocd-prune-vault.md).
- Règle 002 — avant `syncPolicy.automated` + `prune: true` sur une
  Application : valider d'abord en manual-sync (Synced/Healthy).
- Règle 003 — après tout déploiement ArgoCD : `kubectl get applications -n
  argocd` (Synced/Healthy) ET `kubectl get pods -n [namespace]` (Running).

## Méthode de travail avec Claude Code

1. CLAUDE.md est la source de vérité unique — le lire avant toute tâche.

2. Une tâche par prompt — la cadrer avec : objectif, périmètre, contraintes,
   validation attendue.

3. Workflow Explore→Plan→Code→Commit obligatoire pour tout changement
   touchant 2 fichiers ou plus : demander un plan d'abord, aucune
   modification avant validation.

4. Travailler par petites étapes : modifier → lint → test → commit → étape
   suivante.

5. Gates de validation avant tout commit :
   - ansible-lint : 0 violation (profil production)
   - ansible-playbook --check : failed=0
   - ansible-playbook (réel) : failed=0
   - check-idempotence.sh : changed=0

6. Ne jamais afficher de secrets, IPs, tokens ou credentials dans un fichier.

7. Tout nouveau rôle doit suivre la convention de nommage : préfixe
   nomdurole_*.

8. Pas de tag `latest` — toujours pinner les versions avec justification en
   commentaire.

9. Après chaque tâche : git add, git commit (conventional commits), git push.

10. Nouvelle mission = nouvelle session Claude Code pour éviter la pollution
    de contexte.

## Security rules (DevSecOps 2026)

Détail complet : docs/security-rules.md

- Zero trust (mTLS service-to-service) · secrets via ansible-vault/Vault ·
  least privilege par service account.
- Supply chain : checksum sur images/charts ; signature cosign + SBOM
  obligatoires avant S4.
- Audit trail (runs Ansible journalisés, actions K8s via ArgoCD) ·
  vulnerability scanning prévu S3 (Trivy, kube-bench) · network
  segmentation (UFW + NetworkPolicy).
- CI/CD : OIDC pour l'auth cloud, jamais de credentials long-lived ;
  permissions `contents: read` minimum ; actions tierces pinnées par SHA.

## Plan d'exécution

- **S1** : Fondations Git + Ansible + Kubernetes  ← **TERMINÉ**
- **S2** : GitOps + Vault + CI/CD (Celery + RabbitMQ)
- **S3** : PostgreSQL HA + Observabilité
- **S4** : Cloud public + publication GitHub/LinkedIn

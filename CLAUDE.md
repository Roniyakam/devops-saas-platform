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

6. **SECRETS** : ansible-vault pour Ansible, Vault (S2+) pour Kubernetes.
   Jamais en clair dans Git. Voir vault.yml.example.

## Bugs connus et corrections déjà appliquées

- `community.general.ufw state:enabled` → changed à chaque run (bug module) :
  corrigé via garde-fou `ufw status` + `when: 'inactive' in stdout`

- `community.general` v12+ a supprimé `stdout_callback=yaml` :
  corrigé → `stdout_callback=default` + `callback_result_format=yaml`

- Image Scaleway Ubuntu 24.04 = `ubuntu_noble` (pas `ubuntu_jammy` = 22.04)

- Précédence Jinja2 : toujours parenthéser `+` avec `|`
  ex: `('--disable=' + (liste | join(',')))` et non `'--disable=' + liste | join(',')`

- sysctl : fichier dédié `/etc/sysctl.d/99-k8s-platform.conf` (priorité max,
  ne peut pas être écrasé par d'autres confs système)

## Méthode de travail avec Claude Code

1. CLAUDE.md est la source de vérité unique — le lire avant toute tâche.

2. Une tâche par prompt — la cadrer avec : objectif, périmètre, contraintes,
   validation attendue.

3. Pour les changements touchant 3 fichiers ou plus : demander un plan
   d'abord, aucune modification avant validation.

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

- Zero trust : aucune confiance implicite entre composants, mTLS pour les
  communications service-to-service.
- Secrets : ansible-vault pour la couche Ansible, HashiCorp Vault pour la
  couche K8s.
- Least privilege : chaque service account avec uniquement les permissions
  minimales nécessaires.
- Supply chain : toutes les images et charts vérifiées par checksum avant
  utilisation.
- Audit trail : chaque run Ansible journalisé, chaque action K8s uniquement
  via ArgoCD.
- Vulnerability scanning : prévu pour S3 (Trivy sur les images, kube-bench
  sur le cluster).
- Network segmentation : UFW sur toutes les VMs, NetworkPolicy sur les
  namespaces K8s.

## Plan d'exécution

- **S1** : Fondations Git + Ansible + Kubernetes  ← **TERMINÉ**
- **S2** : GitOps + Vault + CI/CD (Celery + RabbitMQ)
- **S3** : PostgreSQL HA + Observabilité
- **S4** : Cloud public + publication GitHub/LinkedIn

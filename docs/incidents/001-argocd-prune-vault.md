# Incident 001 — ArgoCD prune supprime Vault géré par Ansible

**Date**: 2026-06-23
**Sévérité**: P2 — Service Vault indisponible, aucune perte de données
**Durée**: ~15 minutes (détection → restauration)
**Statut**: Résolu ✅

## Chronologie

| Heure | Événement |
|-------|-----------|
| T+0   | deploy-gitops.yml appliqué avec vault Application en syncPolicy.automated |
| T+1   | ArgoCD prune déclenché : ressources vault namespace "non gérées par ArgoCD" détectées |
| T+2   | vault-0 et vault-agent-injector supprimés par ArgoCD |
| T+5   | Incident détecté : kubectl get pods -n vault → no resources found |
| T+8   | Fix appliqué : syncPolicy.automated retiré de gitops/apps/vault/application.yaml |
| T+12  | Vault restauré via ansible-playbook deploy-vault.yml (idempotent) |
| T+15  | Validation complète : vault-0 Running, Sealed=false, rabbitmq intact |

## Cause racine

Collision entre deux systèmes de gestion sur le même namespace :
ArgoCD prune signifie : "tout ce qui existe dans le namespace
mais n'est pas dans mon source Git doit être supprimé."
Le Helm release Ansible n'étant pas dans le source Git ArgoCD,
il a été considéré comme orphelin et supprimé.

## Fix appliqué

Retiré syncPolicy.automated de gitops/apps/vault/application.yaml.
Vault reste en OutOfSync/manual-sync jusqu'à migration complète
vers GitOps pur en S3.

## Règle permanente

**Un namespace = un owner = soit Ansible, soit ArgoCD, jamais les deux.**

## Procédure de migration Ansible → ArgoCD (S3)

Pour éviter de reproduire cet incident lors de la migration Vault en S3 :

1. Désactiver automated sync sur l'Application ArgoCD vault
2. helm uninstall vault -n vault (Ansible cède le contrôle)
3. kubectl delete namespace vault (nettoyage complet)
4. Activer syncPolicy.automated sur Application ArgoCD vault
5. Vérifier : vault-0 Running, Initialized=true, Sealed=false

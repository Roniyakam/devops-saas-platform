#!/usr/bin/env bash
# Session startup script - run at the beginning of every work session
# Ensures Vault is unsealed and all services are healthy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
VAULT_PASS="$HOME/.vault_pass"

echo "=== Session Startup ==="
echo "1. Unsealing Vault..."
# cd indispensable : ansible.cfg (roles_path) n'est auto-détecté que depuis
# le cwd, sinon la résolution du rôle "vault" échoue avec des chemins absolus.
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/scaleway/hosts.ini \
  playbooks/deploy-vault.yml \
  --vault-password-file "$VAULT_PASS" \
  --tags raft 2>&1 | tail -5)

echo "2. Checking Vault status..."
export KUBECONFIG="$ANSIBLE_DIR/fetched/vm-k8s-master-k3s.yaml"
kubectl exec -n vault vault-0 -- vault status 2>/dev/null | \
  grep -E "Sealed|Storage|Initialized"

echo "3. Checking cluster health..."
kubectl get nodes 2>/dev/null | grep -E "Ready|NotReady"
kubectl get applications -n argocd 2>/dev/null | \
  grep -v "Synced.*Healthy" | grep -v "^NAME" || \
  echo "All ArgoCD apps Synced/Healthy"

echo "4. Reconciling RabbitMQ celery-worker user (idempotent — restores it if"
echo "   the rabbitmq pod restarted since persistence.enabled: false wipes"
echo "   rabbitmqctl-created users; see docs/known-issues.md)..."
(cd "$ANSIBLE_DIR" && ansible-playbook -i inventories/scaleway/hosts.ini \
  playbooks/deploy-vault-secrets.yml \
  --vault-password-file "$VAULT_PASS" 2>&1 | tail -5)

echo "=== Ready to work ==="

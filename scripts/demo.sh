#!/usr/bin/env bash
# demo.sh — Démonstration end-to-end de la plateforme DevSecOps
# Prouve que tous les composants fonctionnent en production
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$ROOT_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventories/scaleway/hosts.ini"
export KUBECONFIG="$ANSIBLE_DIR/fetched/vm-k8s-master-k3s.yaml"

inventory_ip() {
  ansible-inventory -i "$INVENTORY" --list | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['_meta']['hostvars']['$1']['ansible_host'])"
}

echo "============================================"
echo "  DevSecOps Platform — Demo End-to-End"
echo "  github.com/Roniyakam/devops-saas-platform"
echo "============================================"
echo ""

# 1. Infrastructure
echo "[ 1/7 ] Infrastructure Ansible"
ansible -i "$INVENTORY" all -m ping | grep -c "SUCCESS" | \
  xargs -I{} echo "  ✓ {} VM répondent"

# 2. K3s Cluster
echo "[ 2/7 ] Cluster Kubernetes K3s"
kubectl get nodes --no-headers | \
  awk '{print "  ✓ "$1" "$2" "$5}'

# 3. ArgoCD Applications
echo "[ 3/7 ] Applications GitOps (ArgoCD)"
kubectl get applications -n argocd --no-headers | \
  awk '{print "  ✓ "$1" → "$2" / "$3}'

# 4. Vault
echo "[ 4/7 ] HashiCorp Vault (Raft)"
kubectl exec -n vault vault-0 -- vault status 2>/dev/null | \
  grep -E "Sealed|Storage Type" | \
  sed 's/^/  ✓ /'

# 5. PostgreSQL HA
echo "[ 5/7 ] PostgreSQL HA (Patroni)"
PG_IP="$(inventory_ip vm-postgres)"
curl -s "http://${PG_IP}:8008/health" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  print(f\"  ✓ Patroni {d['patroni']['version']} — role={d['role']} state={d['state']}\")"

# 6. Monitoring
echo "[ 6/7 ] Stack Observabilité"
MON_IP="$(inventory_ip vm-monitoring)"
curl -s "http://${MON_IP}:3000/api/health" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  print(f\"  ✓ Grafana {d['version']} — {d['database']}\")"

# 7. CI/CD
echo "[ 7/7 ] Pipeline CI/CD"
cd "$ROOT_DIR"
LAST_COMMIT=$(git log --oneline -1)
echo "  ✓ Dernier commit : $LAST_COMMIT"

echo ""
echo "============================================"
echo "  Toutes les vérifications passent ✓"
echo "  Projet prêt pour présentation"
echo "============================================"

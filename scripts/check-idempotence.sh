#!/usr/bin/env bash
# check-idempotence.sh — Vérifie qu'un playbook Ansible est idempotent (changed=0 au 2e run)
# Usage : ./scripts/check-idempotence.sh <inventaire> <playbook>
# Exemple : ./scripts/check-idempotence.sh inventories/scaleway/hosts.ini playbooks/site.yml
#
# RÈGLE NON-NÉGOCIABLE : changed=0 est une gate de qualité, pas une option.
# Ce script doit passer avant tout commit.

set -euo pipefail

INVENTORY="${1:-inventories/scaleway/hosts.ini}"
PLAYBOOK="${2:-playbooks/site.yml}"

if [[ ! -f "${INVENTORY}" ]]; then
    echo "ERROR: Inventaire introuvable : ${INVENTORY}"
    exit 1
fi

if [[ ! -f "${PLAYBOOK}" ]]; then
    echo "ERROR: Playbook introuvable : ${PLAYBOOK}"
    exit 1
fi

echo "=========================================="
echo "VÉRIFICATION D'IDEMPOTENCE"
echo "Inventaire : ${INVENTORY}"
echo "Playbook   : ${PLAYBOOK}"
echo "=========================================="
echo ""
echo "Run 1 (état initial)..."
echo ""

# Run 1 — état initial, on affiche juste le résumé
ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" \
    --extra-vars "ansible_user=root" \
    2>&1 | tail -20

echo ""
echo "=========================================="
echo "Run 2 (test idempotence — changed doit être 0)..."
echo ""

# Run 2 — capture la sortie pour analyser le résultat
OUTPUT=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" \
    --extra-vars "ansible_user=root" \
    2>&1)

echo "${OUTPUT}" | tail -20

# Vérification : changed=0 ?
CHANGED=$(echo "${OUTPUT}" | grep -oP 'changed=\K[0-9]+' | tail -1 || echo "N/A")
FAILED=$(echo "${OUTPUT}" | grep -oP 'failed=\K[0-9]+' | tail -1 || echo "N/A")

echo ""
echo "=========================================="
echo "RÉSULTAT IDEMPOTENCE"
echo "changed : ${CHANGED}  (attendu : 0)"
echo "failed  : ${FAILED}  (attendu : 0)"
echo "=========================================="

if [[ "${CHANGED}" == "0" && "${FAILED}" == "0" ]]; then
    echo "✓ IDEMPOTENCE VALIDÉE — Playbook prêt pour commit."
    exit 0
else
    echo "✗ IDEMPOTENCE ÉCHOUÉE — Corriger avant commit !"
    exit 1
fi

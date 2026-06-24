# Security rules (DevSecOps 2026)

Référencé depuis CLAUDE.md (règles non négociables). Détail complet des
règles de sécurité appliquées sur ce projet.

- **Zero trust** : aucune confiance implicite entre composants, mTLS pour
  les communications service-to-service.
- **Secrets** : ansible-vault pour la couche Ansible, HashiCorp Vault
  (stockage Raft — jamais inmem en production, voir docs/architecture.md)
  pour la couche K8s. Jamais en clair dans Git.
- **Least privilege** : chaque service account avec uniquement les
  permissions minimales nécessaires.
- **Supply chain** :
  - toutes les images et charts vérifiées par checksum avant utilisation
  - images signées (cosign) obligatoire avant S4
  - SBOM généré sur tout build d'image conteneur, obligatoire avant S4
- **Audit trail** : chaque run Ansible journalisé, chaque action K8s
  uniquement via ArgoCD (ou via le rôle Ansible propriétaire du namespace —
  voir docs/incidents/001-argocd-prune-vault.md).
- **Vulnerability scanning** : prévu pour S3 (Trivy sur les images,
  kube-bench sur le cluster).
- **Network segmentation** : UFW sur toutes les VMs, NetworkPolicy sur les
  namespaces K8s.
- **CI/CD** :
  - OIDC pour toute authentification cloud depuis la CI, jamais de
    credentials long-lived stockés en secret GitHub
  - gates obligatoires avant merge : `ansible-lint` (profil production) +
    `gitleaks` (voir `.github/workflows/ci.yml`)
  - permissions GitHub Actions : `contents: read` minimum, jamais `write`
    sauf besoin explicite
  - toutes les actions tierces pinnées par SHA, jamais par tag

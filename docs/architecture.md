# Architecture

## Vault Architecture

- **Actuel** : 1 nœud, stockage Raft (Integrated Storage). Contrainte de
  portfolio (1 seule VM K3s worker disponible) — pas une recommandation de
  production.
- **Cible production** : 5 nœuds Raft répartis sur 3 zones de disponibilité,
  + auto-unseal via KMS cloud (`seal "awskms"` / `"azurekeyvault"` /
  `"gcpckms"` dans la config serveur), pour ne plus dépendre d'une clé de
  unseal manuelle stockée localement.
- **Pourquoi pas inmem** : le mode dev (`server.dev.enabled=true`, stockage
  `inmem`) perd l'intégralité des secrets, policies et configuration
  `auth/kubernetes` à chaque restart du pod `vault-0` — constaté deux fois en
  pratique sur ce projet, avec pour conséquence des pods Celery bloqués en
  `Init:CrashLoop` (403 sur `auth/kubernetes/login`, faute de configuration
  d'auth restaurée).
- **Chemin de migration vers la HA** : augmenter `vault_ha_replicas` à 3 puis
  5, ajouter une entrée `retry_join` par nœud dans la stanza `storage "raft"`
  du values.yaml (`roles/vault/templates/vault-values.yaml.j2`), puis ajouter
  la stanza `seal` d'auto-unseal correspondant au KMS cloud choisi.
- **Secrets Postgres** : `secret/postgres/superuser` et `secret/postgres/app`
  ne sont pas encore bootstrappés — aucun rôle/consommateur Postgres
  n'existe avant S3 (voir plan d'exécution, CLAUDE.md). À ajouter dans
  `playbooks/deploy-vault-secrets.yml` au moment du déploiement Postgres.

## Port Architecture (PostgreSQL HA)

| Port | Service    | Access        | Purpose                    |
|------|------------|---------------|----------------------------|
| 5432 | PostgreSQL | localhost only | Internal Patroni managed   |
| 5433 | HAProxy    | K8s cluster   | Primary writes (health-checked) |
| 5434 | HAProxy    | K8s cluster   | Replica reads (health-checked) |
| 5010 | Patroni    | localhost      | Raft DCS consensus         |
| 6432 | PgBouncer  | K8s cluster   | Connection pooling (recommended entry point) |
| 8008 | Patroni API| vm-infra only  | Health checks, topology    |
| 5000 | HAProxy    | vm-infra only  | Stats dashboard            |

Note: Applications should connect via PgBouncer (6432), not directly
to HAProxy or PostgreSQL.

## TLS et Certificats

### ArgoCD (certificat auto-signé)

ArgoCD utilise un certificat TLS auto-signé généré lors du déploiement
(manifeste officiel `install.yaml`, voir
`roles/k8s_master/tasks/main.yml`). Ce choix est intentionnel pour ce
portfolio :

**Contexte** : ArgoCD n'est pas exposé publiquement. L'accès se fait via
`kubectl port-forward svc/argocd-server -n argocd 8080:443` (loopback
uniquement, 127.0.0.1) exécuté sur vm-infra, combiné à un tunnel SSH depuis
le poste de l'opérateur — voir README.md, section "Accès aux interfaces".
Aucune règle UFW n'ouvre de port ArgoCD vers l'extérieur.

**En production** : migration vers cert-manager + Let's Encrypt ou un
certificat d'entreprise (ex. PKI interne).

```yaml
# Production upgrade path:
# 1. Installer cert-manager dans le cluster
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# 2. Créer un ClusterIssuer Let's Encrypt
# 3. Ajouter annotation sur ArgoCD Ingress:
#    cert-manager.io/cluster-issuer: letsencrypt-prod
# 4. ArgoCD reçoit automatiquement un certificat signé
```

**Trade-off documenté** : sécurité (pas d'exposition publique) prioritaire
sur l'UX (avertissement navigateur acceptable en contexte d'administration
interne).

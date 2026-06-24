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

# Bugs connus et corrections déjà appliquées

Référencé depuis CLAUDE.md (règles non négociables). Détail complet des bugs
de modules/outils déjà rencontrés et corrigés sur ce projet.

- `community.general.ufw state:enabled` → changed à chaque run (bug module) :
  corrigé via garde-fou `ufw status` + `when: 'inactive' in stdout`

- `community.general` v12+ a supprimé `stdout_callback=yaml` :
  corrigé → `stdout_callback=default` + `callback_result_format=yaml`

- Image Scaleway Ubuntu 24.04 = `ubuntu_noble` (pas `ubuntu_jammy` = 22.04)

- Précédence Jinja2 : toujours parenthéser `+` avec `|`
  ex: `('--disable=' + (liste | join(',')))` et non `'--disable=' + liste | join(',')`

- sysctl : fichier dédié `/etc/sysctl.d/99-k8s-platform.conf` (priorité max,
  ne peut pas être écrasé par d'autres confs système)

- Chart Helm `hashicorp/vault` : passer de `server.dev.enabled`/`standalone`
  à `server.ha.raft.enabled` sur un StatefulSet déjà créé échoue avec
  `Forbidden: updates to statefulset spec` (ajout de `volumeClaimTemplates`,
  champ immuable). Sans `dataStorage` préexistant, aucun PVC n'est perdu :
  supprimer le StatefulSet puis ré-exécuter `helm upgrade --install` le
  recrée avec le bon spec. Voir `ansible/roles/vault/tasks/main.yml`.

- Vault hors mode dev (`server.dev.enabled: false`) ne monte plus
  automatiquement le moteur KV-v2 sur `secret/` : un Vault neuf nécessite
  `vault secrets enable -path=secret -version=2 kv` avant tout
  `vault kv put secret/...`, sinon 404. Voir `ansible/roles/vault/tasks/main.yml`.

- `vault status` juste après une recréation de StatefulSet peut répondre
  "connection refused" (stdout vide) avant que le process écoute sur 8200,
  alors que le pod est déjà `Running` : nécessite un `retries`/`until` sur
  `rc in [0, 2]`, pas seulement un `kubectl wait --for=condition=Running`.

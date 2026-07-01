# CI Limitations and Trade-offs

## Playbooks excluded from ansible-lint in CI

**deploy-vault.yml** and **deploy-vault-secrets.yml** are excluded
from automated lint in CI because they:
- Use `kubectl exec` to run Vault CLI commands inside pods
- Require a live Kubernetes cluster with Vault running
- Depend on Python hvac library not available in GitHub Actions runner

**Mitigation**: These playbooks are linted and syntax-checked manually
on vm-infra before every commit, using the same ansible-lint production
profile. The CI gate covers all other playbooks (15/17 = 88% coverage).

**deploy-postgres.yml** and **deploy-monitoring.yml** are not in `.ansible-lint`'s
`exclude_paths`, but are also not in the CI workflow's explicit `ansible-lint`
file list (`.github/workflows/ci.yml`), for a different reason: both declare
`vars_files: [.../vault.yml]`, and `vault.yml` is never committed (gitignored,
ansible-vault-encrypted, local-only). Linting them requires
`ANSIBLE_VAULT_PASSWORD_FILE` pointing at a real decryption key, which CI
doesn't have. Same mitigation as above: linted manually on vm-infra
(`export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass && ansible-lint -f pep8
playbooks/deploy-postgres.yml playbooks/deploy-monitoring.yml`) before every
commit touching them.

**Production upgrade path**: Add a self-hosted GitHub Actions runner
on vm-infra to enable full lint coverage including infrastructure
playbooks. Planned for S4.

## postgres-exporter: placeholder DB credentials

**deploy-monitoring.yml** / **roles/monitoring** deploy `postgres-exporter`
against vm-postgres using `monitoring_postgres_exporter_dsn_user` /
`monitoring_postgres_exporter_dsn_password` (see
`roles/monitoring/defaults/main.yml`). The password is currently a literal
placeholder (`PLACEHOLDER_NO_MONITORING_USER_YET`) — there is no dedicated
read-only PostgreSQL user for monitoring yet, and `postgres-exporter` cannot
authenticate against vm-postgres until one exists.

**Why not fixed now**: creating that user requires changes to
`roles/postgres_ha` (a read-only role/grant, plus a Vault-backed secret
following the same pattern as `postgres_ha_replication_password`), which is
out of scope for the S3 observability task that added the monitoring role.

**Planned fix**: add a `postgres_ha_monitoring_*` read-only role to
`roles/postgres_ha`, source its password from Vault (K8s, via the CSI
provider once available — S4), and replace the placeholder in
`roles/monitoring/defaults/main.yml`. Until then, the `postgres-exporter`
container in the monitoring stack will run but fail to scrape PostgreSQL
metrics (Prometheus will show `up{job="postgres-exporter"} == 0`).

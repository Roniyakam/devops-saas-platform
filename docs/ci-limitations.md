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

## postgres-exporter: uses the PostgreSQL superuser, not a dedicated read-only user

**Resolved**: `postgres-exporter` (`roles/monitoring`) previously used a
literal placeholder password and could never authenticate, leaving
`PostgreSQLDown` permanently firing. `playbooks/deploy-monitoring.yml` now
fetches the real PostgreSQL superuser password from Vault
(`secret/postgres/superuser`) at deploy time — same root-token-via-
`vault-init.yml` mechanism as `playbooks/deploy-postgres.yml` — and injects
it into `DATA_SOURCE_NAME` (see `roles/monitoring/tasks/main.yml`, no
default committed to `roles/monitoring/defaults/main.yml`, règle n°6).

**Known trade-off**: `postgres-exporter` authenticates as the PostgreSQL
superuser (`postgres`), not a dedicated read-only account, which is broader
access than least-privilege calls for (`docs/security-rules.md`). This was
an explicit choice for portfolio speed over creating a new
`postgres_ha_monitoring_*` role/grant in `roles/postgres_ha`.

**Possible follow-up**: add a dedicated read-only `postgres_ha_monitoring_*`
user to `roles/postgres_ha`, store its password in Vault at
`secret/postgres/monitoring` (same pattern as `secret/postgres/app`), and
point `postgres-exporter` at it instead of the superuser. Not scheduled.

**Also resolved**: `roles/monitoring/templates/prometheus.yml.j2`'s
`postgres-exporter` scrape job targeted vm-postgres's IP, even though the
exporter container actually runs on vm-monitoring itself (same
docker-compose stack as Prometheus). Fixed to use the Docker Compose
service name (`postgres-exporter:9187`), same resolution mechanism already
used by `datasources.yml.j2`.

## Grafana dashboards: panels without a real metrics source (not built)

`roles/monitoring/files/dashboards/` ships 3 dashboards (K8s cluster
resources, PostgreSQL/Patroni, platform overview) covering only panels
backed by metrics actually scraped today. Five originally-requested panels
were left out because nothing in this stack currently produces the data:

- **K8s pods count by namespace** — needs kube-state-metrics deployed into
  the cluster and scraped by Prometheus (`kube_pod_info` or similar).
- **HAProxy backend status** — HAProxy (`roles/postgres_ha`) only exposes
  an HTML stats page (`postgres_ha_haproxy_stats_port`), not a
  Prometheus-format endpoint. Needs an haproxy exporter (e.g.
  `prometheus/haproxy-exporter`) pointed at that stats page.
- **PgBouncer pool utilization** — no pgbouncer exporter is deployed. Needs
  one added alongside `postgres-exporter` in `roles/monitoring`.
- **Total requests per service / error rate** — no service in this stack
  currently exports HTTP request metrics; would need each app/API
  instrumented (e.g. via a Prometheus client library) once one exists.

**Why not fixed now**: each of these is a new exporter/container or new
application instrumentation, out of scope for "add dashboards to the
existing stack." Not scheduled.

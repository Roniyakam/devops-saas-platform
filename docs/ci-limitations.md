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

**Production upgrade path**: Add a self-hosted GitHub Actions runner
on vm-infra to enable full lint coverage including infrastructure
playbooks. Planned for S4.

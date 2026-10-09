# ADR-0005: Secrets Manager with External Secrets Operator; values never in state

**Status:** Accepted (Phases 5 and 6)

## Context
The cluster needs a few secrets (a fault-injection token, the Grafana admin password). The repositories are
public, and the read-only plan role can read Terraform state and can be assumed by any pull request.

## Decision
- Terraform creates the Secrets Manager **container** only. The value is written out-of-band
  (`aws secretsmanager put-secret-value`) and rotated by runbook.
- External Secrets Operator (own Pod Identity, read-only on `cloud-lab-platform/<env>/*`) copies the value into
  a Kubernetes Secret; pods load it as an environment variable.

## Consequences
- Nothing secret is in Git or in Terraform state. An earlier version used `random_password` and put the token in
  state; it was removed from state and **rotated**, because S3 versioning keeps old state files.
- Environment variables are read at pod start, so a rotation needs a rollout restart (documented).
- Prod secrets use a 30-day recovery window; dev uses none. Teardown of prod must force-delete them.

## Alternatives considered
- **HashiCorp Vault:** more flexible, but a cluster to run and secure for three small secrets.
- **Sealed Secrets or SOPS:** puts encrypted values in Git and adds key management.

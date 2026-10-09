# ADR-0006: Three repositories and pull-based delivery

**Status:** Accepted (Phase 0, Phase 5)

## Context
Infrastructure, application code and desired cluster state have different owners, change at different speeds and
carry different blast radii.

## Decision
Three repositories: infra, app and gitops. CI builds and scans in the app repo, then commits an image tag to the
gitops repo through a read-write deploy key (the only identity allowed to bypass the PR ruleset there). Argo CD
inside each cluster pulls and applies.

## Consequences
- The app pipeline never touches Terraform; CI never holds cluster credentials, so a compromised pipeline cannot
  reach the cluster directly.
- Git is the audit log of every deploy, and a rollback is a revert.
- Argo CD polls about every 3 minutes by default. A webhook would make it near-instant, but needs Argo CD
  reachable from GitHub, which the private control plane deliberately is not.

## Alternatives considered
- **Monorepo:** simpler to start, but broad permissions and one noisy history.
- **Push-based `kubectl apply` from CI:** needs cluster credentials in CI.

# Runbooks

| Runbook | Use it when |
|---|---|
| [teardown.md](teardown.md) | Shutting an environment down (dev or prod) and proving the account is clean |
| [rebuild-dev.md](rebuild-dev.md) | Bringing dev back from the repository after a teardown |
| [prod-promotion.md](prod-promotion.md) | Promoting the app and infrastructure to production |
| [deploy-rollback.md](deploy-rollback.md) | A deploy is bad and needs to be undone |
| [alert-lab-api-high-error-rate.md](alert-lab-api-high-error-rate.md) | The `LabApiHighErrorRate` alert fires |
| [dlq-triage.md](dlq-triage.md) | The dead-letter queue alarm fires |
| [rotate-chaos-token.md](rotate-chaos-token.md) | Rotating the fault-injection token |

Conventions: examples use the dev names. Replace `dev` with `prod` where noted. Quote every glob and every
bang in zsh, and pass `--context` explicitly when more than one cluster is in your kubeconfig.

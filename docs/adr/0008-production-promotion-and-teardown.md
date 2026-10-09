# ADR-0008: Production promotion and teardown

**Status:** Accepted (Phases 6 and 9)

## Context
Prod must never change as a side effect of a merge, and it should run exactly what dev proved.

## Decision
- **Infra:** a manual `terraform-apply` run into the `production` GitHub Environment: only `main`, a required
  reviewer, admin bypass off, plus the IAM trust that accepts only `environment:production` tokens.
- **App:** a reviewed pull request changes one line (`newTag`) in the prod overlay to a SHA already running in
  dev. Immutable ECR tags make the SHA a fingerprint. Verified by comparing image digests in both clusters.
- **Teardown:** a documented break-glass `terraform destroy` as an admin, after turning off table deletion
  protection, then force-deleting the secrets and deregistering hand-made task definitions.

## Consequences
- Known limitation: approval is evaluated before the plan is computed, so what is approved is "apply what
  `main` says", reviewed earlier as PR plan comments. Next: split plan and apply into separate jobs and apply
  the saved plan artifact after approval.
- Prod safety nets (deletion protection, 30-day secret recovery) are friction on purpose and must be handled
  deliberately at teardown.
- The prod worker was promoted by hand; a gated CI job is the next step.

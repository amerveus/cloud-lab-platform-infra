# ADR-0003: Keyless CI with GitHub OIDC and separate plan and apply roles

**Status:** Accepted (Phase 0, amended in Phase 4)

## Context
CI must read, plan and change AWS without stored credentials, and a pull request must never be able to change
infrastructure.

## Decision
GitHub OIDC federation with distinct roles:

| Role | Permissions | Trusts |
|---|---|---|
| plan | `ReadOnlyAccess` plus write on `*.tflock` | `pull_request` tokens of the infra repo |
| apply | `AdministratorAccess` | only the `dev`, `staging`, `production` environments |
| app | ECR push and ECS worker roll | `refs/heads/main` of the app repo |

Trust policies use GitHub's **immutable subject** format (owner and repo with numeric IDs).

## Consequences
- No AWS keys exist to leak or rotate.
- The apply role is broad because it builds VPCs, EKS and IAM. The control is **who can assume it**, enforced by
  the environment-scoped subject plus GitHub Environment rules (production needs a reviewer, `main` only, admin
  bypass off).
- Next steps for a real organization: a permissions boundary on the apply role and one AWS account per
  environment.

## History
The first push to `main` failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity`. CloudTrail showed
the token's actual subject carried numeric IDs. All three trust policies were updated. Immutable subjects also
stop a deleted repository's name being re-registered to inherit access.

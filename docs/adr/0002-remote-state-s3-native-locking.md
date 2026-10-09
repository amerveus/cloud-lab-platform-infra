# ADR-0002: Remote state in S3 with native locking

**Status:** Accepted (Phase 0)

## Context
State must be shared with CI, versioned, encrypted and locked. The bucket that holds it is itself created by
Terraform.

## Decision
Bootstrap creates the bucket with local state, then migrates its own state into it. The bucket is versioned,
SSE-S3 encrypted, public-access-blocked, ACL-disabled, TLS-only, with a 90-day noncurrent-version lifecycle and
`prevent_destroy`. Locking uses `use_lockfile = true` (Terraform 1.10 and later), a `.tflock` object written
with a conditional write. One state key per environment.

## Consequences
- No DynamoDB lock table to create, secure and pay for.
- Requires Terraform 1.11 or newer (pinned).
- The read-only plan role needs write access to `*.tflock` objects only.
- The plan role can read state, so **no secret value may ever be in state** (see ADR-0005).

## Alternatives considered
- **DynamoDB lock table:** the older pattern; works but is an extra moving part.
- **Terraform Cloud:** adds an external dependency and cost for no capability we lack.

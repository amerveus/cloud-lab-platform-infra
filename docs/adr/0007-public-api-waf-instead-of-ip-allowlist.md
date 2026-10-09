# ADR-0007: Public API with WAF and compensating controls, not an IP allowlist

**Status:** Accepted (Phase 5)

## Context
The API accepts unauthenticated writes. Restricting the ALB to a single admin address would put a personal IP
address in a public repository.

## Decision
Leave the internet-facing ALB open and compensate:

1. **AWS WAF** rate limit of 100 requests per IP per 5 minutes plus the AWS managed common rule set.
2. The fault-injection endpoint returns **404** unless fault injection is enabled **and** a constant-time
   comparison of an `X-Chaos-Token` header succeeds. It fails closed if no token is configured.
3. **Budget alarms** as a cost backstop, and the ALB is deleted after the demo.

## Consequences
- Anyone can create lab requests, within the WAF limit. Real use needs authentication.
- Rate-based rules stop sustained floods but are not a precise counter: a 250-request burst was allowed, then
  blocked once the rule engaged.
- A 404 (not 401) means an attacker learns nothing about the endpoint's existence.

# ADR-0001: One composition module, three thin environment roots

**Status:** Accepted (Phase 1)

## Context
The platform needs dev, staging and prod. Copying VPC and EKS code into three folders guarantees they drift
apart, and a reviewer cannot tell which differences are intentional.

## Decision
`modules/platform` wires the community VPC and EKS modules and the modules we wrote (data, messaging,
workload-iam, ecs-worker, ops-host). Each environment root is about 25 lines and states only what differs.

## Consequences
- A fix or feature lands in every environment, and `diff -ru envs/dev envs/prod` shows only intentional
  differences: network ranges, NAT per AZ, deletion protection, node floor and ceiling.
- A module change has a wider blast radius. Mitigated by planning all three environments on every PR and
  applying to dev first.
- Each environment has its own state key, so state is isolated.

## Alternatives considered
- **Copy and paste per environment:** drifts immediately.
- **Terraform workspaces:** same code and backend, and the active workspace is invisible in the diff, which makes
  running the wrong environment easier.
- **Terragrunt:** another tool to learn and run for a problem a module already solves.

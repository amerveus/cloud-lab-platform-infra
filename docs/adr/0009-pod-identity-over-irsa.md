# ADR-0009: EKS Pod Identity instead of IRSA

**Status:** Accepted (Phases 2 and 5)

## Context
Pods need AWS permissions without static keys or node-wide credentials.

## Decision
Use EKS Pod Identity: an IAM role trusting `pods.eks.amazonaws.com` plus an association that binds it to one
service account in one namespace. Four associations exist: lab-api, the load balancer controller, External
Secrets and Alertmanager.

## Consequences
- No per-cluster OIDC trust to maintain, and the role is reusable across clusters.
- EKS injects `AWS_CONTAINER_CREDENTIALS_FULL_URI` and a token file; the node's Pod Identity agent hands out
  short-lived credentials.
- The EKS module still creates an OIDC provider, so IRSA remains available for any chart that supports only it.

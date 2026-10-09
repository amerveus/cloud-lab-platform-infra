# Architecture decision records

Each record states the context, the decision, its consequences, and the alternatives considered.

| # | Decision |
|---|---|
| [0001](0001-composition-module-three-environments.md) | One composition module, three thin environment roots |
| [0002](0002-remote-state-s3-native-locking.md) | Remote state in S3 with native locking |
| [0003](0003-keyless-ci-oidc-plan-apply-roles.md) | Keyless CI with GitHub OIDC and separate plan and apply roles |
| [0004](0004-eks-api-ecs-fargate-spot-worker.md) | API on EKS, queue worker on ECS Fargate Spot |
| [0005](0005-secrets-manager-external-secrets-out-of-state.md) | Secrets Manager with External Secrets; values never in state |
| [0006](0006-three-repositories-pull-based-delivery.md) | Three repositories and pull-based delivery |
| [0007](0007-public-api-waf-instead-of-ip-allowlist.md) | Public API with WAF and compensating controls |
| [0008](0008-production-promotion-and-teardown.md) | Production promotion and teardown |
| [0009](0009-pod-identity-over-irsa.md) | EKS Pod Identity instead of IRSA |
| [0010](0010-observability-and-alert-routing.md) | Prometheus for app signals, CloudWatch for SQS, routed alerts |

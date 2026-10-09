# Architecture

## Components

| Layer | Component | Notes |
|---|---|---|
| Edge | AWS WAF, internet-facing ALB | WAF: 100 requests per IP per 5 minutes plus the AWS managed common rule set. The ALB is created by the AWS Load Balancer Controller from an Ingress, so Terraform does not own it |
| API | `lab-api` on EKS | 2 replicas, Pod Security `restricted`, readiness gates, `preStop` sleep, Pod Identity |
| Queue | SQS `lab-jobs` and a DLQ | Long polling, visibility timeout 60 s, redrive after 3 receives, SSE-SQS |
| Worker | `lab-worker` on ECS Fargate Spot | Warm minimum of 1, step scaling on visible messages, SIGTERM-safe |
| Data | DynamoDB `lab_requests` | On-demand, point-in-time recovery, deletion protection in prod |
| Notify | SNS topic with an email subscription | Used by the worker and by Alertmanager and CloudWatch alarms |
| GitOps | Argo CD (app-of-apps) | Auto-sync, prune, self-heal; one root per cluster |
| Secrets | Secrets Manager and External Secrets Operator | Values set out-of-band; ESO read-only on one environment's path |
| Observability | kube-prometheus-stack, Grafana, Alertmanager | Dashboards and rules are code in the gitops repo |
| Config mgmt | Ansible over SSM | Dynamic inventory by EC2 tag; no SSH, no port 22 |
| Identity | GitHub OIDC, EKS Pod Identity, ECS task roles | No static keys anywhere |

## Request flow

1. A student calls `POST /labs`. WAF rate-limits, the ALB forwards to a healthy pod IP.
2. `lab-api` writes the record to DynamoDB (`PENDING`) and sends a message to SQS.
3. `lab-worker` long-polls the queue, marks the record `PROVISIONING`, processes it, marks it `READY`, publishes
   to SNS, and only then deletes the message.
4. If the worker fails, the message is not deleted. It reappears after the visibility timeout. After three
   receives SQS moves it to the DLQ, and a CloudWatch alarm emails.

## Delivery flow

- **Infra:** PR, then `terraform-plan` (Trivy, fmt, validate, three plans as comments), then merge, then
  `terraform-apply` for dev. Prod is a manual run that waits for a required reviewer.
- **App:** PR runs tests and a Trivy image scan with no AWS credentials. Merge to `main` assumes a role through
  OIDC, pushes images tagged with the commit SHA, commits the new tag to the gitops repo through a deploy
  key, and rolls the ECS worker.
- **Cluster:** Argo CD pulls the gitops repo and applies it. CI never holds cluster credentials.

## Trust boundaries

| Principal | Can do | Cannot do |
|---|---|---|
| Pull request workflow (plan role) | Read AWS, take the state lock | Change anything |
| Dev environment job (apply role) | Apply dev | Run for any other branch |
| Production environment job (apply role) | Apply prod after approval | Run from a feature branch or without a reviewer |
| App CI (app role, `main` only) | Push to ECR, roll the dev worker | Touch Terraform or the cluster |
| lab-api pod | Put and get items on one table, send to one queue | Anything else |
| Alertmanager pod | `sns:Publish` on one topic | Anything else |
| External Secrets pod | Read secrets under one environment's path | Read another environment's secrets |

## Networking

One VPC per environment, two AZs. Public /24 subnets hold the ALB and NAT gateways; private /19 subnets hold
nodes, pods, Fargate tasks and the ops host. The EKS API endpoint is public but restricted to the admin address
and also reachable privately by the nodes. Access is through EKS access entries (API mode), with no `aws-auth`
ConfigMap and creator-admin turned off.

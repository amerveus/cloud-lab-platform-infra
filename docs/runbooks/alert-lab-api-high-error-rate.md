# Runbook: LabApiHighErrorRate

**What it means:** more than 5 percent of lab-api requests returned 5xx over the last 2 minutes, and that held
for 2 minutes (`for: 2m`). `/healthz` is excluded from the ratio. Routed by the `team=cloud-lab-platform` label
to SNS and email.

## Triage (about 5 minutes)

1. **Is it real traffic or a test?** Fault injection (`/chaos/error`) produces exactly this alert. Check
   whether someone is running a demo.
2. **Look at the dashboard** (Grafana, lab-api): is the error ratio rising or flat, and which route? Check p95
   latency and the request rate panel.
3. **Was there a deploy?** `kubectl -n argocd get application lab-api-dev` and the Argo CD history. If yes,
   roll back: [deploy-rollback.md](deploy-rollback.md).
4. **Read the logs:**
   `kubectl -n lab-app logs -l app.kubernetes.io/name=lab-api --tail=100` (structured JSON; look for exceptions).
5. **Check dependencies.** `AccessDenied` or `ResourceNotFound` from boto3 points at IAM or a missing resource
   (Pod Identity association, table or queue name in the ConfigMap). Throttling points at DynamoDB.
6. **Check the edge.** ALB target health:
   `aws elbv2 describe-target-health --target-group-arn <arn>`. 5xx from the ALB itself (502/503/504) with healthy
   pods suggests a rollout or readiness problem.

## Known false positives

- At very low traffic a single error is a large ratio. Next improvement: require a minimum request rate.
- Prometheus's own `/metrics` scrapes count as successful requests and dilute the ratio (about 79 percent
  instead of 100 in the demo). Next improvement: exclude `/metrics`.

## Silence

For a planned test: Alertmanager UI (port-forward `svc/kps-alertmanager` 9093), Silences, match
`alertname=LabApiHighErrorRate`, set an expiry. Never silence without an expiry.

## Resolve

The alert clears about 2 minutes after the ratio drops below 5 percent. A resolved notification follows after
the next group interval (up to 5 minutes).

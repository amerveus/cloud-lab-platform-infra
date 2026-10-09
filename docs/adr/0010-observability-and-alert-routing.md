# ADR-0010: Prometheus for app signals, CloudWatch for SQS, and routed alerts

**Status:** Accepted (Phases 2 and 8)

## Context
Two kinds of signal: application metrics (request rate, errors, latency) and AWS service state (queue age,
DLQ depth). A default Prometheus stack also ships about a hundred alerts, including a Watchdog that fires
forever.

## Decision
- kube-prometheus-stack through Argo CD; `ServiceMonitor`, `PrometheusRule` and the Grafana dashboard are code.
- CloudWatch alarms watch SQS age and DLQ depth, where the metrics are native.
- Alertmanager routes only alerts labelled `team=cloud-lab-platform` to SNS (through Pod Identity); everything
  else goes to a null receiver, which avoids alert fatigue.
- Rules use `for: 2m` so one bad minute never pages anyone. The error ratio excludes `/healthz`.

## Consequences
- In the demo, errors at about 4 requests per second produced a `pending` alert, `firing` exactly two minutes
  later, and an email about three minutes after the first error.
- The ratio was diluted by Prometheus's own `/metrics` scrapes (about 79 percent instead of 100). Next: exclude
  `/metrics` and require a minimum request rate.
- Two alerting systems, each on the signal it sees natively.

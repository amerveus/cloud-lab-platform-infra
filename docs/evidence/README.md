# Evidence

Screenshots captured during the build, and what each one proves. Terminal and console captures were taken at
the time of the events described in the lessons tables.

| File | Phase | Proves |
|---|---|---|
| 01-phase0-merged-pr.png | 0 | The first change reached `main` through a pull request |
| 02-oidc-apply-role-trust.png | 0 | The apply role trusts only environment-scoped GitHub tokens |
| 03-budget.png | 0 | Monthly budget with 75 and 100 USD alerts |
| 04-state-bucket-versioning.png | 0 | State bucket versioning and encryption |
| 05-argocd-lab-api-dev-tree.png | 5 | lab-api synced from Git: deployment, pods, service, config |
| 06-drift-self-heal-watch.png | 5 | Scaled to 5 by hand, reverted to 2 within about a second |
| 07-argocd-apps.png | 5 | Platform add-ons managed as Argo CD applications |
| 08-waf-traffic-overview.png | 5 | WAF counted 250 allowed and 10 blocked requests |
| 09-waf-rate-limit-sankey.png | 5 | The rate-limit rule is what blocked the traffic |
| 10-pr-three-plan-comments.png | 6 | One plan comment per environment on a pull request |
| 11-apply-dev-green.png | 6 | GitHub applied dev through OIDC after the merge |
| 12-prod-gate-waiting.png | 6 | A manual prod run waiting for a reviewer |
| 13-ansible-idempotent-changed0.png | 7 | Ansible second run: `changed=0` |
| 14-pr-ops-host-dev-plan.png | 7 | The ops host reviewed as a plan before it existed |
| 15-grafana-error-spike.png | 8 | The error ratio spike during the alert demo |
| 16-prometheus-targets.png | 8 | Prometheus scraping lab-api pods and the Ansible-configured host |
| 17-alert-firing-email.png | 8 | The firing alert reached the inbox (address cropped out) |
| 18-prod-gate-waiting.png | 9 | The production approval gate waiting |
| 19-prod-gate-approve.png | 9 | The approval dialog with a reviewer comment |
| 20-prod-apply-running.png | 9 | Approved and deploying |
| 21-prod-argocd-apps.png | 9 | Prod's own Argo CD with root and lab-api-prod |
| 22-prod-argocd-tree-a.png | 9 | Prod app tree synced from the promotion commit |
| 23-prod-argocd-tree-b.png | 9 | Prod root app and its child |
| 24-prod-lab-ready-same-digest.png | 9 | A lab READY in prod and identical image digests in dev and prod |
| 25-grafana-24h.png | 8 | One day of dashboard history including the demo spike |

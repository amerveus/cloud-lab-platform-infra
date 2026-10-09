# Runbook: promote to production

Prod never changes as a side effect of a merge. Infrastructure and application are promoted separately.

## Preconditions

- The change has been running in dev and verified.
- The latest infra PR shows the expected prod plan comment (read it: this is what you are approving).
- vCPU quota covers a second environment (`aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A`).
- Budget has headroom: prod is about $7 per day.

## 1. Infrastructure

```bash
gh workflow run terraform-apply.yml --repo amerveus/cloud-lab-platform-infra --ref main -f environment=prod
gh run view --web            # Review deployments, tick production, comment, Approve and deploy
gh run watch --exit-status   # about 15 minutes
```

Gates in front of this run: manual dispatch only, `production` Environment restricted to `main`, a required
reviewer, admin bypass off, and an IAM trust that accepts only `environment:production` tokens.

Verify: EKS `ACTIVE`; two NAT gateways; table deletion protection and point-in-time recovery on; nodes `Ready`.

## 2. Application (one line, reviewed)

In the gitops repo, `apps/lab-api/overlays/prod/kustomization.yaml` pins `newTag` to a SHA already running in
dev. Open a PR that changes that single line. After merge, prod's Argo CD syncs it.

Prod's GitOps loop is separate: `argocd/prod/root.yaml` is applied once to the prod cluster, and dev's root
(`argocd/apps`, non-recursive) never reads `argocd/prod`.

## 3. Worker

CI's app role is scoped to dev, so promote the worker by hand using the same steps as
[rebuild-dev.md](rebuild-dev.md) section 5, with prod names (`cloud-lab-platform-prod`, the prod task
definition family, and the SHA from the prod overlay).

## 4. Prove it is the same artifact

```bash
for C in cloud-lab-dev cloud-lab-prod; do
  kubectl --context $C -n lab-app get pod -l app.kubernetes.io/name=lab-api \
    -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'; echo
done
```

Both lines must end with the same `sha256:` digest. Then create a lab through the prod API (port-forward) and
confirm it reaches `READY`, a record appears in the prod table, and the prod worker logs `job_done`.

## Gotchas

- `aws eks update-kubeconfig` switches your **current** context. Pass `--context` explicitly in every command.
- The base overlay must contain only what every environment can run (a ServiceMonitor in the base breaks an
  environment without Prometheus CRDs).
- The worker starts from a placeholder image until step 3, so ECS reports `CannotPullContainerError`.
- Approval fires before the plan is computed; re-read the PR plan comment before approving.

## Teardown

See [teardown.md](teardown.md), prod section.

# Runbook: roll a bad deploy back

Decide which layer changed, then use the matching path. Every path is a reviewable change, not a hotfix on a
live system (Argo CD would revert manual edits within seconds anyway).

## API (lab-api on EKS)

1. Find the last good image tag: `git log -p -- apps/lab-api/overlays/dev/kustomization.yaml` in the gitops
   repo. CI commits one `deploy(dev): lab-api <sha>` per merge.
2. Open a PR that sets `newTag` back to that SHA. Merge. Argo CD syncs within about 3 minutes; hard-refresh to
   speed it up:
   `kubectl -n argocd annotate application lab-api-dev argocd.argoproj.io/refresh=hard --overwrite`
3. Watch the rollout: `kubectl -n lab-app rollout status deploy/lab-api`. With readiness gates and the
   `preStop` sleep, the rollout is slower than a plain one by design and should drop no requests.
4. Fix forward in the app repo. **The next merge to `main` bumps the tag again**, so a pinned rollback does not
   hold; revert or fix the code too.

## Worker (ECS)

Terraform ignores `task_definition`, so a manual revision change does not cause drift.

```bash
aws ecs list-task-definitions --family-prefix cloud-lab-platform-dev --sort DESC --max-items 5
aws ecs update-service --cluster cloud-lab-platform-dev --service lab-worker --task-definition <previous-arn>
aws ecs wait services-stable --cluster cloud-lab-platform-dev --services lab-worker
```

Messages in flight are safe: unfinished work reappears after the visibility timeout.

## Configuration (ConfigMap or overlay)

The ConfigMap name carries a content hash, so reverting the overlay change renames it back and rolls the pods
automatically.

## Infrastructure

Revert the PR. For dev the pipeline applies it on merge; for prod, dispatch `terraform-apply` and approve.
Read the plan first: a revert can propose deletions, and prod has deletion protection that will (rightly) stop
you from deleting the table.

## Verify

Create a lab and confirm `READY`, check the Grafana dashboard for error rate and latency, and confirm no alert
is firing.

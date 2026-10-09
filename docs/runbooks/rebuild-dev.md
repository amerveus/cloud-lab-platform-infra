# Runbook: rebuild dev from the repository

Time: about 45 minutes, of which the Terraform apply is about 16. Cost: about $6 to $7 per day while it is up.

## 0. Preconditions

- Bootstrap is intact: state bucket, ECR repositories with images, GitHub OIDC roles.
- GitHub Environments and the repository variables and secrets still exist (see the README).
- Your public IP still matches the `TF_ADMIN_CIDRS` secret. If it changed, update the secret first.

## 1. Build the infrastructure

```bash
gh workflow run terraform-apply.yml --repo amerveus/cloud-lab-platform-infra --ref main -f environment=dev
gh run watch --exit-status
aws eks update-kubeconfig --name cloud-lab-platform-dev --alias cloud-lab-dev
kubectl --context cloud-lab-dev get nodes        # 3 nodes Ready
```

## 2. Refresh the three values that a rebuild invalidates

These are hard-coded in the **gitops** repo and change with every rebuild. Update them in one pull request:

| Value | Where | Get the new one |
|---|---|---|
| VPC id | `argocd/apps/aws-load-balancer-controller.yaml` (`vpcId`) | `terraform output vpc_id` in `envs/dev` |
| WAF web ACL ARN | `apps/lab-api/overlays/dev/ingress.yaml` (`wafv2-acl-arn` annotation) | `terraform output api_waf_acl_arn` |
| Ops host private IP | `argocd/apps/kube-prometheus-stack.yaml` (`additionalScrapeConfigs` target) | `aws ec2 describe-instances --instance-ids $(terraform output -raw ops_host_instance_id) --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text` |

Known improvement: drive these from Terraform outputs so a rebuild needs no manual edit.

## 3. Set secret values out-of-band

Terraform recreated the secret containers empty. External Secrets will report errors until they have values.

```bash
aws secretsmanager put-secret-value --secret-id cloud-lab-platform/dev/chaos-token --secret-string "$(openssl rand -hex 16)"
PW=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
aws secretsmanager put-secret-value --secret-id cloud-lab-platform/dev/grafana-admin \
  --secret-string "{\"admin-user\":\"admin\",\"admin-password\":\"$PW\"}"
unset PW
```

## 4. Bootstrap GitOps (the one manual apply)

```bash
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update argo
helm install argocd argo/argo-cd --kube-context cloud-lab-dev -n argocd --create-namespace \
  --version 10.9.6 --set dex.enabled=false --set notifications.enabled=false --wait --timeout 10m
kubectl --context cloud-lab-dev apply -f argocd/root.yaml        # from the gitops repo
kubectl --context cloud-lab-dev -n argocd get applications
```

Expected: seven applications reach `Synced` and `Healthy`. Ordering notes:

- `lab-api-dev` ships a ServiceMonitor, which needs the Prometheus CRDs from `kube-prometheus-stack`. If the
  first sync fails with `no matches for kind ServiceMonitor`, wait for `kube-prometheus-stack` to be healthy,
  hard-refresh the app, and click **Sync** once. Sync waves or a `retry` block are the formal fix.
- `monitoring-config` and `secret-store` already carry a retry with backoff.

## 5. Give the ECS worker a real image

Terraform starts the worker from a placeholder tag, so the service fails to pull until a real revision exists.
Promote the SHA currently pinned in the dev overlay:

```bash
SHA=$(sed -n 's/^ *newTag: *//p' apps/lab-api/overlays/dev/kustomization.yaml)
IMG=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/cloud-lab-platform/lab-worker:$SHA
TD=$(aws ecs describe-services --cluster cloud-lab-platform-dev --services lab-worker --query 'services[0].taskDefinition' --output text)
aws ecs describe-task-definition --task-definition "$TD" --query taskDefinition --output json \
  | jq --arg IMG "$IMG" 'del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy) | .containerDefinitions[0].image = $IMG' > /tmp/td.json
NEW=$(aws ecs register-task-definition --cli-input-json file:///tmp/td.json --query taskDefinition.taskDefinitionArn --output text)
aws ecs update-service --cluster cloud-lab-platform-dev --service lab-worker --task-definition "$NEW" --query service.serviceName --output text
```

## 6. Confirm the SNS subscription

A new email subscription is created. Click the confirmation link in the email. If a mail scanner already
opened the unsubscribe link, confirm with `--authenticate-on-unsubscribe true` (see Phase 2 lessons).

## 7. Verify end to end

```bash
ALB=$(kubectl --context cloud-lab-dev -n lab-app get ingress lab-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ID=$(curl -s -X POST "http://$ALB/labs" -H 'content-type: application/json' -d '{"student_id":"you","lab_type":"eks-intro"}' | jq -r .request_id)
sleep 8; curl -s "http://$ALB/labs/$ID" | jq .status        # READY
```

The ALB takes about 4 to 5 minutes to provision and pass health checks; do not recreate it right before a demo.

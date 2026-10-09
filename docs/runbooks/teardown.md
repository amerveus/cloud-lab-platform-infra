# Runbook: tear an environment down

An environment costs about $6 to $7 per day. Tear it down when it is not in use. The bootstrap layer (state
bucket, ECR, GitHub OIDC roles, budget) costs pennies and stays.

## Why the order matters

The load balancer controller creates the ALB from a Kubernetes Ingress, so **Terraform does not own the ALB**.
The ALB's network interfaces and security groups sit in subnets Terraform must delete. If the cluster or VPC
is destroyed first, `terraform destroy` fails with `DependencyViolation`. Argo CD's self-heal would also
recreate the Ingress the moment you delete it, so Argo must be frozen first.

## Dev

```bash
CTX=cloud-lab-dev

# 1. Freeze Argo CD so it cannot recreate the Ingress
kubectl --context $CTX -n argocd scale statefulset argocd-application-controller --replicas=0

# 2. Delete the Ingress, then wait for the ALB to disappear
kubectl --context $CTX -n lab-app delete ingress lab-api --timeout=300s
while aws elbv2 describe-load-balancers --names cloud-lab-platform-dev-lab-api >/dev/null 2>&1; do echo "deleting..."; sleep 10; done

# 3. Nothing the controller created should remain
aws elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupName' --output text
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<VPC_ID> --query 'SecurityGroups[].GroupName' --output text | tr '\t' '\n' | grep '^k8s-' || echo none

# 4. Destroy
cd envs/dev
terraform init -backend-config=backend.hcl
terraform destroy          # read the plan: ~106 to destroy, every name contains "dev", VPC id matches

# 5. Remove what Terraform never owned: task definition revisions registered by CI
aws ecs list-task-definitions --family-prefix cloud-lab-platform-dev --status ACTIVE --query 'taskDefinitionArns[]' --output text \
  | tr '\t' '\n' | while read TD; do [ -n "$TD" ] && aws ecs deregister-task-definition --task-definition "$TD" >/dev/null; done
kubectl config delete-context $CTX
```

Dev secrets have no recovery window, so they are deleted with the environment.

## Prod

Prod has deletion protection and a 30-day secret recovery window on purpose. Handle both deliberately.

```bash
# 1. Turn off the table's deletion protection (the safety net you must disable on purpose)
T=$(aws dynamodb list-tables --query "TableNames[?contains(@, 'prod')]|[0]" --output text)
aws dynamodb update-table --table-name $T --no-deletion-protection-enabled

# 2. Destroy as an admin (break-glass: there is no destroy workflow by design)
cd envs/prod
terraform init -input=false -reconfigure \
  -backend-config="bucket=cloud-lab-platform-tfstate-<ACCOUNT_ID>" \
  -backend-config="key=envs/prod/terraform.tfstate" \
  -backend-config="region=us-east-1" -backend-config="encrypt=true" -backend-config="use_lockfile=true"
terraform destroy -var-file=../dev/terraform.tfvars      # ~110 to destroy, names contain "prod"

# 3. Clear the secret names (recovery window would otherwise reserve them for 30 days)
for S in chaos-token grafana-admin; do
  aws secretsmanager delete-secret --secret-id cloud-lab-platform/prod/$S --force-delete-without-recovery
done

# 4. Deregister the task definition revision registered by hand during promotion
aws ecs deregister-task-definition --task-definition cloud-lab-platform-prod-lab-worker:2
```

If prod ever gets a load balancer controller and an Ingress, follow the dev steps 1 to 3 first.

## Prove the account is clean (use direct checks, not the tagging index)

The Resource Groups Tagging API is eventually consistent and keeps listing deleted resources for a while. Check
each service directly.

```bash
aws eks list-clusters --query clusters --output text
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,pending --query 'Reservations[].Instances[].InstanceId' --output text
aws ec2 describe-nat-gateways --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId' --output text
aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text
aws ec2 describe-vpcs --filters Name=tag:Project,Values=cloud-lab-platform --query 'Vpcs[].VpcId' --output text
aws ecs list-clusters --query clusterArns --output text
aws secretsmanager list-secrets --filters Key=name,Values=cloud-lab-platform --query 'SecretList[].Name' --output text
aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[].Name' --output text
aws dynamodb list-tables --query TableNames --output text
aws sqs list-queues --query QueueUrls --output text
aws sns list-topics --query 'Topics[].TopicArn' --output text
```

Every line should be empty (the CLI prints `None` for some services). Expected survivors: KMS keys in
`PendingDeletion` (a mandatory waiting period, not billed) and ECS clusters shown as `INACTIVE`.

**Elastic IPs that look orphaned:** the two ALB nodes show up as untagged addresses attached to network
interfaces described `ELB app/...`. They belong to the ALB, are not releasable by hand, and disappear with it.

## What stays

State bucket, ECR repositories and images, GitHub OIDC provider and roles, the budget. The state bucket has
`prevent_destroy`; removing the bootstrap layer is a deliberate, separate act.

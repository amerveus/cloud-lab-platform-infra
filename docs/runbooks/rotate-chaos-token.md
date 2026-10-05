# Runbook: rotate the chaos token

The value lives only in AWS Secrets Manager. Terraform manages the secret's
container, never its value, so the token never enters Terraform state
(which the PR plan role can read).

1. Write a new value (never printed):
       NEW=$(openssl rand -hex 16)
       aws secretsmanager put-secret-value --secret-id cloud-lab-platform/dev/chaos-token \
         --secret-string "$NEW" --query VersionId --output text
       unset NEW

2. Make External Secrets sync now instead of within the hour:
       kubectl -n lab-app annotate externalsecret lab-api-secrets force-sync=$(date +%s) --overwrite

3. Restart the pods (environment variables are read once, at start):
       kubectl -n lab-app rollout restart deploy/lab-api
       kubectl -n lab-app rollout status deploy/lab-api

4. Verify with the new value:
       TOKEN=$(aws secretsmanager get-secret-value --secret-id cloud-lab-platform/dev/chaos-token \
         --query SecretString --output text)
       curl -s -o /dev/null -w '%{http_code}\n' -H "X-Chaos-Token: $TOKEN" http://<alb>/chaos/error   # 500
       unset TOKEN

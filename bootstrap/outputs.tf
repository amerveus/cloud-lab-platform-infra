output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "github_oidc_provider_arn" {
  value = local.github_oidc_arn
}

output "gha_plan_role_arn" {
  value = aws_iam_role.gha_plan.arn
}

output "gha_apply_role_arn" {
  value = aws_iam_role.gha_apply.arn
}

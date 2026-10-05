resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = (var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
  : data.aws_iam_openid_connect_provider.github[0].arn)
}

# GitHub immutable OIDC subjects: owner@<owner_id>/repo@<repo_id>.
# Numeric IDs never change or get reused, so a deleted-then-recreated repo
# with the same name can never satisfy these trust policies.
locals {
  gh_owner  = "${var.github_org}@330062012"
  infra_sub = "repo:${local.gh_owner}/cloud-lab-platform-infra@1393463997"
  app_sub   = "repo:${local.gh_owner}/cloud-lab-platform-app@1393464179"
}

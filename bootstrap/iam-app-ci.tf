locals {
  app_repo = "${var.github_org}/cloud-lab-platform-app"
  acct     = data.aws_caller_identity.current.account_id
}

# ---------- APP CI role: push images + roll the worker, from main only ----------
data "aws_iam_policy_document" "app_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.app_sub}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_app" {
  name                 = "cloud-lab-platform-gha-app"
  assume_role_policy   = data.aws_iam_policy_document.app_ci_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "app_ci" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
    ]
    resources = [for r in aws_ecr_repository.app : r.arn]
  }

  statement {
    sid       = "EcsTaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "EcsWorkerService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:aws:ecs:${var.region}:${local.acct}:service/cloud-lab-platform-*/lab-worker"]
  }

  statement {
    sid       = "PassWorkerRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.acct}:role/cloud-lab-platform-*-worker-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "app_ci" {
  name   = "app-ci"
  role   = aws_iam_role.gha_app.id
  policy = data.aws_iam_policy_document.app_ci.json
}

output "gha_app_role_arn" {
  value = aws_iam_role.gha_app.arn
}

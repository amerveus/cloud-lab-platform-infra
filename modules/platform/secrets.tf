# Application secrets live in AWS Secrets Manager; External Secrets Operator
# syncs them into Kubernetes. Nothing secret is ever committed to Git.

data "aws_caller_identity" "current" {}

resource "random_password" "chaos_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "chaos_token" {
  name                    = "cloud-lab-platform/${var.env}/chaos-token"
  description             = "Gates the fault-injection endpoint used for alert demos"
  recovery_window_in_days = var.deletion_protection ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "chaos_token" {
  secret_id     = aws_secretsmanager_secret.chaos_token.id
  secret_string = random_password.chaos_token.result
}

# External Secrets Operator: read-only access to this environment's secrets only
data "aws_iam_policy_document" "eso_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${local.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
}

data "aws_iam_policy_document" "eso" {
  statement {
    sid       = "ReadThisEnvironmentsSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:cloud-lab-platform/${var.env}/*"]
  }
}

resource "aws_iam_role_policy" "eso" {
  name   = "read-env-secrets"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}

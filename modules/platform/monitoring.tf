# Observability: Grafana admin secret container (value set out-of-band) and
# Alertmanager's permission to publish alerts to the notifications SNS topic.

resource "aws_secretsmanager_secret" "grafana_admin" {
  name                    = "cloud-lab-platform/${var.env}/grafana-admin"
  description             = "Grafana admin credentials, synced into the cluster by External Secrets"
  recovery_window_in_days = var.deletion_protection ? 30 : 0
}

data "aws_iam_policy_document" "alertmanager_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alertmanager" {
  name               = "${local.name}-alertmanager"
  assume_role_policy = data.aws_iam_policy_document.alertmanager_trust.json
}

data "aws_iam_policy_document" "alertmanager" {
  statement {
    sid       = "PublishAlerts"
    actions   = ["sns:Publish"]
    resources = [module.messaging.topic_arn]
  }
}

resource "aws_iam_role_policy" "alertmanager" {
  name   = "publish-alerts"
  role   = aws_iam_role.alertmanager.id
  policy = data.aws_iam_policy_document.alertmanager.json
}

resource "aws_eks_pod_identity_association" "alertmanager" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "kps-alertmanager"
  role_arn        = aws_iam_role.alertmanager.arn
}

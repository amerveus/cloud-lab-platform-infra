variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "queue_arn" {
  type = string
}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lab_api" {
  name               = "${var.name}-lab-api"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "lab_api" {
  statement {
    sid       = "LabRequestsTable"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [var.table_arn]
  }

  statement {
    sid       = "EnqueueLabJobs"
    actions   = ["sqs:SendMessage"]
    resources = [var.queue_arn]
  }
}

resource "aws_iam_role_policy" "lab_api" {
  name   = "lab-api"
  role   = aws_iam_role.lab_api.id
  policy = data.aws_iam_policy_document.lab_api.json
}

resource "aws_eks_pod_identity_association" "lab_api" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.lab_api.arn
}

output "lab_api_role_arn" {
  value = aws_iam_role.lab_api.arn
}

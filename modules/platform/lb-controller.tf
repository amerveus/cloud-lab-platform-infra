# AWS Load Balancer Controller: creates ALBs from Kubernetes Ingress objects.
# The policy file is AWS's official policy for the pinned controller version.

resource "aws_iam_policy" "lb_controller" {
  name   = "${local.name}-aws-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

data "aws_iam_policy_document" "lb_controller_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${local.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_trust.json
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn
}

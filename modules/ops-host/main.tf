# Ops host: a small EC2 instance configured by Ansible, reachable ONLY through
# AWS Systems Manager. No SSH key, no inbound port 22, IMDSv2 enforced.

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "node_security_group_id" {
  description = "EKS node SG: Prometheus on the nodes scrapes node_exporter on 9100"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- S3 bucket the Ansible SSM connection uses for file transfer ----------
resource "aws_s3_bucket" "ssm_transfer" {
  bucket        = "${var.name}-ssm-transfer-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "ssm_transfer" {
  bucket                  = aws_s3_bucket.ssm_transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
  rule {
    id     = "expire-transfers"
    status = "Enabled"
    filter {}
    expiration {
      days = 1
    }
  }
}

# ---------- IAM: SSM core + this bucket only ----------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ops" {
  name               = "${var.name}-ops-host"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ops.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "transfer" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.ssm_transfer.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.ssm_transfer.arn]
  }
}

resource "aws_iam_role_policy" "transfer" {
  name   = "ssm-transfer-bucket"
  role   = aws_iam_role.ops.id
  policy = data.aws_iam_policy_document.transfer.json
}

resource "aws_iam_instance_profile" "ops" {
  name = "${var.name}-ops-host"
  role = aws_iam_role.ops.name
}

# ---------- Network: nothing inbound except node_exporter from EKS nodes ----------
resource "aws_security_group" "ops" {
  name        = "${var.name}-ops-host"
  description = "Ops host: no SSH; node_exporter from EKS nodes; HTTPS out"
  vpc_id      = var.vpc_id

  ingress {
    description     = "node_exporter scraped by Prometheus on EKS nodes"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    description = "HTTPS: SSM, package repos, GitHub releases"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ops" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ops.id]
  iam_instance_profile   = aws_iam_instance_profile.ops.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  tags = {
    Name = "${var.name}-ops-host"
    Role = "ops-host"
  }

  lifecycle {
    # Patching is Ansible's job; replacing the instance for a new AMI is a deliberate change.
    ignore_changes = [ami]
  }
}

output "instance_id" {
  value = aws_instance.ops.id
}

output "ssm_transfer_bucket" {
  value = aws_s3_bucket.ssm_transfer.bucket
}

output "security_group_id" {
  value = aws_security_group.ops.id
}

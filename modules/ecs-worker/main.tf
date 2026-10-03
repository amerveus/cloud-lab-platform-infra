variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "image" {
  type = string
}

variable "queue_url" {
  type = string
}

variable "queue_arn" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "table_name" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "topic_arn" {
  type = string
}

variable "max_tasks" {
  type    = number
  default = 3
}

resource "aws_ecs_cluster" "this" {
  name = var.name
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.name}/lab-worker"
  retention_in_days = 14
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: used by the ECS agent to pull the image and write logs
resource "aws_iam_role" "execution" {
  name               = "${var.name}-worker-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: used by the worker's own code
resource "aws_iam_role" "task" {
  name               = "${var.name}-worker-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "ConsumeLabJobs"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [var.queue_arn]
  }

  statement {
    sid       = "UpdateLabRequests"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [var.table_arn]
  }

  statement {
    sid       = "Notify"
    actions   = ["sns:Publish"]
    resources = [var.topic_arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "lab-worker"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_security_group" "worker" {
  name        = "${var.name}-worker"
  description = "lab-worker tasks: outbound only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.name}-lab-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "lab-worker"
    image     = var.image
    essential = true
    environment = [
      { name = "AWS_REGION", value = var.region },
      { name = "QUEUE_URL", value = var.queue_url },
      { name = "TABLE_NAME", value = var.table_name },
      { name = "TOPIC_ARN", value = var.topic_arn },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.worker.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])
}

resource "aws_ecs_service" "worker" {
  name            = "lab-worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 0

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.worker.id]
    assign_public_ip = false
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.worker.name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_family" {
  value = aws_ecs_task_definition.worker.family
}

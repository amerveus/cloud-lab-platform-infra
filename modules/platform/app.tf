data "aws_region" "current" {}

data "aws_ecr_repository" "worker" {
  name = "cloud-lab-platform/lab-worker"
}

module "data" {
  source = "../data"

  name                = local.name
  deletion_protection = var.deletion_protection
}

module "messaging" {
  source = "../messaging"

  name        = local.name
  alert_email = var.alert_email
}

module "lab_api_identity" {
  source = "../workload-iam"

  name            = local.name
  cluster_name    = module.eks.cluster_name
  namespace       = "lab-app"
  service_account = "lab-api"
  table_arn       = module.data.table_arn
  queue_arn       = module.messaging.queue_arn
}

module "ecs_worker" {
  source = "../ecs-worker"

  name       = local.name
  region     = data.aws_region.current.region
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  image      = "${data.aws_ecr_repository.worker.repository_url}:${var.worker_image_tag}"
  queue_url  = module.messaging.queue_url
  queue_arn  = module.messaging.queue_arn
  queue_name = module.messaging.queue_name
  table_name = module.data.table_name
  table_arn  = module.data.table_arn
  topic_arn  = module.messaging.topic_arn
}

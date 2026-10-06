output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "table_name" {
  value = module.data.table_name
}

output "queue_url" {
  value = module.messaging.queue_url
}

output "dlq_url" {
  value = module.messaging.dlq_url
}

output "topic_arn" {
  value = module.messaging.topic_arn
}

output "lab_api_role_arn" {
  value = module.lab_api_identity.lab_api_role_arn
}

output "ecs_cluster_name" {
  value = module.ecs_worker.cluster_name
}

output "worker_service_name" {
  value = module.ecs_worker.service_name
}

output "api_waf_acl_arn" {
  value = aws_wafv2_web_acl.api.arn
}

output "ops_host_instance_id" {
  value = module.ops_host.instance_id
}

output "ssm_transfer_bucket" {
  value = module.ops_host.ssm_transfer_bucket
}

output "vpc_id" {
  value = module.platform.vpc_id
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_endpoint" {
  value = module.platform.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.platform.cluster_name} --alias cloud-lab-staging"
}

output "table_name" {
  value = module.platform.table_name
}

output "queue_url" {
  value = module.platform.queue_url
}

output "dlq_url" {
  value = module.platform.dlq_url
}

output "topic_arn" {
  value = module.platform.topic_arn
}

output "lab_api_role_arn" {
  value = module.platform.lab_api_role_arn
}

output "ecs_cluster_name" {
  value = module.platform.ecs_cluster_name
}

output "api_waf_acl_arn" {
  value = module.platform.api_waf_acl_arn
}

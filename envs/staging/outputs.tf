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

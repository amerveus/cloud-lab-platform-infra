module "platform" {
  source = "../../modules/platform"

  env                  = "staging"
  vpc_cidr             = "10.20.0.0/16"
  azs                  = var.azs
  private_subnet_cidrs = ["10.20.0.0/19", "10.20.32.0/19"]
  public_subnet_cidrs  = ["10.20.128.0/24", "10.20.129.0/24"]
  single_nat_gateway   = true

  kubernetes_version           = var.kubernetes_version
  endpoint_public_access_cidrs = var.admin_cidrs
  cluster_admin_arns           = var.cluster_admin_arns

  node_instance_types = ["t3.small"]
  node_min_size       = 2
  node_desired_size   = 2
  node_max_size       = 3
}

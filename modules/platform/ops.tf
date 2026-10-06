module "ops_host" {
  source = "../ops-host"

  name                   = local.name
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.private_subnets[0]
  node_security_group_id = module.eks.node_security_group_id
}

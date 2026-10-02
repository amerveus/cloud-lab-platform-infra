variable "env" {
  type = string
}

variable "name_prefix" {
  type    = string
  default = "cloud-lab-platform"
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap); false = one NAT per AZ (resilient)"
  type        = bool
}

variable "kubernetes_version" {
  type = string
}

variable "endpoint_public_access_cidrs" {
  description = "Public IPs allowed to reach the EKS API"
  type        = list(string)
}

variable "cluster_admin_arns" {
  description = "IAM principals granted cluster-admin through EKS access entries"
  type        = list(string)
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_max_pods" {
  description = "Pods per node once prefix delegation is on (memory is the real limit on t3.small)"
  type        = number
  default     = 35
}

locals {
  name = "${var.name_prefix}-${var.env}"
}

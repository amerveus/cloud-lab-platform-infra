variable "azs" {
  description = "Two AZ names whose AZ IDs are supported by EKS (not use1-az3)"
  type        = list(string)
}

variable "kubernetes_version" {
  type = string
}

variable "admin_cidrs" {
  description = "Your public IP as x.x.x.x/32"
  type        = list(string)
  sensitive   = true
}

variable "cluster_admin_arns" {
  type = list(string)
}

variable "alert_email" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type    = string
  default = "amerveus"
}

variable "alert_email" {
  description = "Where AWS Budgets sends cost alerts"
  type        = string
  sensitive   = true
}

variable "monthly_budget_usd" {
  type    = number
  default = 100
}

variable "create_github_oidc_provider" {
  description = "false when the account already has the GitHub OIDC provider"
  type        = bool
  default     = true
}

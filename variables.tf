variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "portfolio"
}

variable "budget_alert_email" {
  description = "Email address that gets the budget alert. Set this in terraform.tfvars (not committed)"
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget in USD"
  type        = string
  default     = "10"
}

variable "enable_guardduty" {
  description = "Turn GuardDuty on. Needs an account on a paid plan (not the AWS Free plan)"
  type        = bool
  default     = false
}

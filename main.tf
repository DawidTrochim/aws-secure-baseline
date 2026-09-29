# Monthly cost budget. Sends me an email if actual spend goes over 80% of the limit,
# and again if AWS forecasts I will go over 100%. This was the first thing I built
# so I don't get a surprise bill while learning.
resource "aws_budgets_budget" "monthly" {
  name         = "aws-secure-baseline-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

# GuardDuty is AWS's threat detection service. It reads CloudTrail, VPC flow logs and
# DNS logs in the background and raises findings for things like crypto mining,
# logins from unusual places or an instance talking to a known bad IP.
# My account is on the AWS Free plan, which doesn't allow GuardDuty, so it is off by
# default. Set enable_guardduty = true once the account is on a paid plan.
resource "aws_guardduty_detector" "main" {
  #checkov:skip=CKV2_AWS_3:This is a single standalone account, not part of an AWS Organization, so there is no org-wide GuardDuty setup to configure.
  count  = var.enable_guardduty ? 1 : 0
  enable = true
}

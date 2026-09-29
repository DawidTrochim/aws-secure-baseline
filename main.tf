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

output "instance_id" {
  description = "EC2 instance ID - use this with 'aws ssm start-session --target'"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "cloudtrail_bucket" {
  description = "S3 bucket that CloudTrail writes logs to"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID (empty if GuardDuty is turned off)"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""
}

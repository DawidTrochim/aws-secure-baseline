# Used to get my account ID so the bucket name is unique and the policy can reference it.
data "aws_caller_identity" "current" {}

# S3 bucket that stores the CloudTrail logs.
# force_destroy lets "terraform destroy" delete it even when it has logs in it.
# That is fine for a lab - in a real account I would not want this.
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "secure-baseline-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Block every kind of public access to the bucket, even if someone adds a public policy by mistake.
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning keeps old copies of objects, so logs can't be silently overwritten.
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket policy that allows the CloudTrail service to write logs into the bucket,
# but only for my trail (the SourceArn condition).
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/secure-baseline-trail"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/secure-baseline-trail"
          }
        }
      }
    ]
  })
}

# CloudTrail records API calls made in the account (who did what, when, from where).
# Single region to keep this project small.
resource "aws_cloudtrail" "main" {
  name                          = "secure-baseline-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false

  # the bucket policy has to exist before CloudTrail checks it can write to the bucket
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

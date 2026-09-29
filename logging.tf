# Used to get my account ID so the bucket name is unique and the policy can reference it.
data "aws_caller_identity" "current" {}

# S3 bucket that stores the CloudTrail logs.
# force_destroy lets "terraform destroy" delete it even when it has logs in it.
# That is fine for a lab - in a real account I would not want this.
resource "aws_s3_bucket" "cloudtrail" {
  #checkov:skip=CKV_AWS_18:Access logging would need a second bucket just for logs about the log bucket. CloudTrail already records who changes this bucket.
  #checkov:skip=CKV_AWS_144:Cross-region replication needs a second bucket in another region and doubles storage cost. Not worth it for lab logs.
  #checkov:skip=CKV2_AWS_62:Nothing consumes S3 event notifications in this project.
  #checkov:skip=CKV_AWS_145:Bucket uses SSE-S3 (AES256) default encryption. A customer managed KMS key adds cost and key policy work - planned as a next step.
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

# Lifecycle rule so logs don't pile up forever and cost money.
# Logs are kept for a year, old versions for 90 days after they are replaced.
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # lifecycle rules on a versioned bucket should be created after versioning is on
  depends_on = [aws_s3_bucket_versioning.cloudtrail]
}

# Encrypt everything in the bucket by default. SSE-S3 (AES256) uses keys that AWS manages
# for me, so there is no extra cost. S3 does this by default now, but I want it written down.
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy that allows the CloudTrail service to write logs into the bucket,
# but only for my trail (the SourceArn condition), and lets VPC flow logs write too.
# It also blocks any access that isn't over HTTPS.
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
      },
      # the next two statements let the VPC flow logs service write into the vpc-flow-logs/ folder
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/vpc-flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      # refuse any request that isn't over HTTPS
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# CloudTrail records API calls made in the account (who did what, when, from where).
# Single region to keep this project small.
resource "aws_cloudtrail" "main" {
  #checkov:skip=CKV_AWS_252:No one would subscribe to an SNS topic for log delivery in this lab.
  #checkov:skip=CKV2_AWS_10:Sending CloudTrail to CloudWatch Logs adds ingestion cost. Planned as a next step together with metric filters and alarms.
  #checkov:skip=CKV_AWS_67:Single-region on purpose to keep this project small. The account already has a separate multi-region trail that covers all regions.
  #checkov:skip=CKV_AWS_35:Logs are encrypted with SSE-S3 (bucket default). A customer managed KMS key costs about $1/month plus API calls and needs a key policy for CloudTrail - planned as a next step, not needed for a lab.
  name                          = "secure-baseline-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false

  # CloudTrail writes a signed digest file every hour, so I can prove later that
  # nobody edited or deleted log files after they were delivered.
  enable_log_file_validation = true

  # the bucket policy has to exist before CloudTrail checks it can write to the bucket
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

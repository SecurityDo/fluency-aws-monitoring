provider "aws" {
  region     = var.region
}

resource "random_string" "random" {
  length           = 6
  special          = false
  numeric          = false
  upper            = false
}

locals {
  s3metricbucket = "fluency-awsmonitoring-${var.accountID}-${var.region}-${random_string.random.result}"
  queue_name = "fluency_awsmonitoring_s3notify_${random_string.random.result}"
}

resource "aws_s3_bucket" "metricbucket" {
  bucket = local.s3metricbucket
} 

resource "aws_s3_bucket_lifecycle_configuration" "metricbucket" {
  bucket = aws_s3_bucket.metricbucket.bucket
  rule {
    id      = "expire"
    status = "Enabled"
    expiration {
      days = var.expireDays
    }
  }
}


resource "aws_sqs_queue" "bucket_s3_event_queue" {
  name = local.queue_name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:*:${local.queue_name}",
      "Condition": { 
        "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.metricbucket.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = local.s3metricbucket
  queue {
    queue_arn     = aws_sqs_queue.bucket_s3_event_queue.arn
    events        = ["s3:ObjectCreated:*"]
  }
}

resource "aws_iam_policy" "billing_read_policy" {
  name = "fluency_awsmonitoring_billing_${random_string.random.result}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "awsBillingRead",
      "Effect": "Allow",
      "Resource": "*",
      "Action": ["ec2:DescribeReservedInstances", "ec2:DescribeReservedInstancesListings",
      "savingsplans:Describe*", "pricing:DescribeServices", "pricing:GetAttributeValues", "pricing:GetProducts" ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "metric_bucket_read_policy" {
  name = "fluency_awsmonitoring_bucket_${random_string.random.result}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "metricS3Read",
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.metricbucket.arn}",
      "Action": ["s3:GetObject"]
    },
    {
      "Sid": "metricSQSRead",
      "Effect": "Allow",
      "Resource": "${aws_sqs_queue.bucket_s3_event_queue.arn}",
      "Action": ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
    }

  ]
}
POLICY
}

resource "aws_iam_role" "assume_role" {
  name = var.role

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
    "${aws_iam_policy.metric_bucket_read_policy.arn}",
    "${aws_iam_policy.billing_read_policy.arn}"
  ]
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::993024041442:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${var.externalID}"
                }
            }
        }
    ]
}
POLICY
}


output "MetricQueueURL" {
  value =  aws_sqs_queue.bucket_s3_event_queue.id
  description = "SQS Metric Notification Queue URL"
}

output "MetricBucket" {
  value =  local.s3metricbucket
  description = "s3 bucket name"
}


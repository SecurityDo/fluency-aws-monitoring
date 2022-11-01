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

resource "aws_iam_role_policy_attachment" "metric_bucket_policy" {
  role = "${var.role}"
  policy_arn = "${aws_iam_policy.metric_bucket_read_policy.arn}"
}

output "MetricQueueURL" {
  value =  aws_sqs_queue.bucket_s3_event_queue.id
  description = "SQS Metric Notification Queue URL"
}

output "MetricBucket" {
  value =  local.s3metricbucket
  description = "s3 bucket name"
}


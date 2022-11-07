provider "aws" {
  region     = var.region
}

/*
resource "random_string" "random" {
  length           = 6
  special          = false
  numeric          = false
  upper            = false
}
*/

locals {
  s3metricbucket = "fluency-metricstreams-${var.accountID}-${var.region}"
  queue_name = "fluency_metricstream_s3_notification_${var.region}"
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


resource "aws_iam_role" "FluencyMetricStreamS3Role" {
  name = "fluency_metricstream_s3_${var.region}"
  description = "allow Kinesis Firehose to store data in S3"
  inline_policy {
    name = "s3_access"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
          Effect   = "Allow"
          Resource = [
            "arn:aws:s3:::fluency-metricstreams-${var.accountID}-${var.region}",
            "arn:aws:s3:::fluency-metricstreams-${var.accountID}-${var.region}/*"
          ]
        },
      ]
    })
  }
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "firehose.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}


resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "fluency_metricstream_${var.region}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.FluencyMetricStreamS3Role.arn
    bucket_arn = aws_s3_bucket.metricbucket.arn
  }
}

resource "aws_iam_role" "FluencyMetricStreamRole" {
  name = "fluency_metricstream_${var.region}"
  description = "allow CloudWatch MetricStreams to publish to Kinesis Firehose"
  inline_policy {
    name = "firehose_put"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
          Effect   = "Allow"
          Resource = aws_kinesis_firehose_delivery_stream.arn
        }
      ]
    })
  }
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "streams.metrics.cloudwatch.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

resource "aws_cloudwatch_metric_stream" "regionalMetricStream" {
  name          = "fluency_metricstream_${var.region}"
  role_arn      = aws_iam_role.FluencyMetricStreamRole.arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn
  output_format = "json"

  include_filter {
    namespace = "AWS/EC2"
  }

  include_filter {
    namespace = "AWS/EBS"
  }
}

output "MetricStreamName" {
  value =  "fluency_metricstream_${var.region}"
  description = "Regional metric stream name"
}

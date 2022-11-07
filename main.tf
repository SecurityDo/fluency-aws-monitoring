provider "aws" {
  region     = var.region
}


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
  name = "fluency_metricstream_read_${var.accountID}-${var.region}"
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



resource "aws_iam_policy" "FluencyPolicyR" {
  name = "fluency_aws_monitoring"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "passRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::*:role/fluency_metricstream_*",
      "Action": [
        "iam:PassRole" 
      ]
    },
    {
      "Sid": "metricStream",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "cloudwatch:ListMetricStreams", 
        "cloudwatch:GetMetricStream",
        "cloudwatch:PutMetricStream", 
        "cloudwatch:DeleteMetricStream", 
        "cloudwatch:StartMetricStreams", 
        "cloudwatch:StopMetricStreams" 
      ]
    },
    {
      "Sid": "awsBillingRead",
      "Effect": "Allow",
      "Resource": "*",
      "Action": ["ec2:DescribeReservedInstances", "ec2:DescribeReservedInstancesListings",
      "savingsplans:Describe*", "pricing:DescribeServices", "pricing:GetAttributeValues", "pricing:GetProducts" ]
    },
    {
      "Sid": "awsBillingRead",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "apigateway:GET",
        "autoscaling:Describe*",
        "autoscaling:DescribeAutoScalingGroups",
        "cloudfront:GetDistributionConfig",
        "cloudfront:ListDistributions",
        "cloudfront:ListTagsForResource",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "logs:Get*",
        "logs:List*",
        "logs:Describe*",
        "sns:Get*",
        "sns:List*",
        "directconnect:DescribeConnections",
        "dynamodb:DescribeTable",
        "dynamodb:ListTables",
        "dynamodb:ListTagsOfResource",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeNatGateways",
        "ec2:DescribeRegions",
        "ec2:DescribeReservedInstances",
        "ec2:DescribeReservedInstancesListings",
        "ec2:DescribeReservedInstancesModifications",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ecs:DescribeClusters",
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:ListTagsForResource",
        "ecs:ListTaskDefinitions",
        "ecs:ListTasks",
        "elasticache:DescribeCacheClusters",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticmapreduce:DescribeCluster",
        "elasticmapreduce:ListClusters",
        "es:DescribeElasticsearchDomain",
        "es:ListDomainNames",
        "kinesis:DescribeStream",
        "kinesis:ListShards",
        "kinesis:ListStreams",
        "kinesis:ListTagsForStream",
        "lambda:GetAlias",
        "lambda:ListFunctions",
        "lambda:ListTags",
        "organizations:DescribeOrganization",
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters",
        "rds:ListTagsForResource",
        "redshift:DescribeClusters",
        "redshift:DescribeLoggingStatus",
        "s3:GetBucketLocation",
        "s3:GetBucketLogging",
        "s3:GetBucketNotification",
        "s3:GetBucketTagging",
        "s3:ListAllMyBuckets",
        "s3:ListBucket",
        "s3:GetBucketNotificationConfiguration",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ListQueues",
        "sqs:ListQueueTags",
        "states:ListActivities",
        "states:ListStateMachines",
        "tag:GetResources",
        "workspaces:DescribeWorkspaces"
      ]
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
    "${aws_iam_policy.metric_bucket_read_policy.arn}",
    "${aws_iam_policy.FluencyPolicyR.arn}"
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
          Resource = aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn
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

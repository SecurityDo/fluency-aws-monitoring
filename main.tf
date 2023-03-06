provider "aws" {
  region     = var.region
}


locals {

  fluencyaccount = var.aws_type == "aws" ? "${var.fluencyAccountID}" : "024776754335"

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
      "Resource": "arn:${var.aws_type}:iam::*:role/fluency_metricstream_*",
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
      "Sid": "readOnlyAccess",
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
        "firehose:DescribeDeliveryStream",
        "firehose:ListDeliveryStreams",
        "health:Describe*",
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
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ListQueues",
        "sqs:ListQueueTags",
        "states:ListActivities",
        "states:ListStateMachines",
        "tag:GetResources",
        "tag:GetTagKeys",
        "tag:GetTagValues",
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
    "${aws_iam_policy.FluencyPolicyR.arn}"
  ]
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:${var.aws_type}:iam::${local.fluencyaccount}:root"
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

/*
module "regionConfig" {
  source           = "./modules/region_config"
  region     = var.region
  accountID = var.accountID
  role = aws_iam_role.assume_role.name
  expireDays = var.expireDays
}
*/

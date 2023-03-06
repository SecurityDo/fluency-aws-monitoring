
variable "accountID" {
  description = "provider's AWS accountID"
}

variable "region" {
  description = "AWS region"
}

variable "role" {
  description = "IAM role name"
  default = "fluency-aws-monitoring"
}

variable "fluencyAccountID" {
  description = "Fluency AWS AccountID"
  default = "162820009300"
}

variable "externalID" {
  description = "external ID for role fluency-aws-monitoring"
}

variable "aws_type" {
  description = "aws cloud type"
  default = "aws"
  // or "aws-us-gov"
}

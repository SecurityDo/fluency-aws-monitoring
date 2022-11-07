
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

variable "expireDays" {
  default = 14
}

variable "externalID" {
  description = "external ID for role fluency-aws-monitoring"
}


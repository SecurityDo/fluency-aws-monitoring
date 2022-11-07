
variable "accountID" {
  description = "provider's AWS accountID"
}

variable "region" {
  description = "AWS Region"
}

variable "role" {
  description = "IAM role name"
  default = "fluency-aws-monitoring"
}

variable "expireDays" {
  default = 14
}




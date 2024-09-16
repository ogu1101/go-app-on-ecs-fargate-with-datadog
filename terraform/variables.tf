variable "region" {
  description = "region"
}

variable "env" {
  description = "environment"
}

variable "service" {
  description = "service"
}

variable "ver" {
  description = "version"
}

variable "global_ip_address" {
  description = "global ip address"
}

variable "team" {
  description = "team"
}

variable "creator" {
  description = "creator"
}

variable "dd_api_key" {
  description = "datadog api key"
}

data "aws_caller_identity" "current" {}

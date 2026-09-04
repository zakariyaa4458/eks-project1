variable "app_ecr_repo" {
  type        = set(string)
  description = "1 repo for each 9 service"
  default     = ["api-gateway", "dashboard-api", "inventory-service", "notification-service", "order-service", "payment-service", "scheduler", "shipping-service", "worker"]

}


variable "region" {
  type    = string
  default = "eu-west-2"

}

#variable "domain" {
# type    = string
#default = "ecommerce.zakariyaalab.com"

#}

#variable "aws_eks_cluster" {
# type = string
#}

#variable "aws_eks_cluster_eks_cluster_certificate_authority_data" {
# type = string

#}

#variable "aws_eks_cluster_eks_cluster_endpoint" {
# type = string

#}

variable "ip_address" {
  type    = string
  default = "81.151.155.181/32"

}

variable "aws_key_arn" {
  type = string

}

variable "aws_key_ecr_arn" {
  type = string

}

variable "cloudwatch_key_arn" {
  type = string

}

variable "aws_account_id" {
  type = string

}

variable "eks_role_arn" {
  type = string

}

variable "flow_log_role_arn" {
  type = string

}
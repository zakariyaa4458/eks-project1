variable "region" {
  type    = string
  default = "us-east-1"

}

variable "aws_vpc_id" {
  type        = string
  description = "vpc id"

}

variable "aws_iam_openid_connect_provider_arn" {
  type = string

}

variable "aws_eks_cluster" {
  type = string

}

variable "aws_eks_cluster_eks_cluster_identity_oidc_issuer" {
  type = string

}

variable "aws_eks_cluster_eks_cluster_name" {
  type = string

}


variable "eks_oidc_issuer_url" {
  type = string

}

variable "aws_account_id" {
  type = string
}

variable "postgres_secret_arn" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

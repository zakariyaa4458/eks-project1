variable "region" {
  type    = string
  default = "eu-west-2"

}

variable "aws_vpc_id" {
    type = string
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
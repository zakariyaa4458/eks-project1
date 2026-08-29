variable "app_ecr_repo" {
  type        = set(string)
  description = "1 repo for each 9 service"

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
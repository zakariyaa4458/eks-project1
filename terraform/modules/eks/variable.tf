variable "region" {
  type    = string
  default = "eu-west-2"

}

variable "aws_sg_eks_worker_node" {
    type = string
    }
  


variable "aws_public_subnet_ids" {
    type = list(string)
  
}

variable "aws_private_subnet_ids" {
    type = list(string)
  
}

variable "aws_sg_eks_control_plane" {
    type = string
  
}

variable "aws_iam_role_policy_attachment_eks_cluster_policy" {
    type = string 
  
}

variable "aws_iam_role_eks_role" {
    type = string
  
}

variable "aws_iam_role_node_group_role" {
    type = string
  
}

variable "ip_address" {
  type = string
  default = "81.151.155.181/32"
  
}

variable "aws_key_arn"{
    type = string
    
}

variable "aws_account_id" {
    type = string
  
}

variable "eks_role_arn" {
    type = string

}

variable "aws_iam_role_node_group_role" {
    type = string
  
}
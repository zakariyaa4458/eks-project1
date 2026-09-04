variable "region" {
  type    = string
  default = "eu-west-2"

}

variable "aws_vpc_id" {
    type = string
  
}

variable "aws_vpc_id_cidr_block" {
    type = string
  
}

variable "aws_iam_role_policy_flow_log_policy" {
    type = string
  
}

variable "aws_iam_role_flow_log_role" {
    type = string
  
}

#variable "aws_cloudwatch_log_group_flow_log_group" {
 #   type = string
  
#}

variable "cloudwatch_key_arn" {
    type = string
  
}

variable "aws_account_id" {
    type = string
  
}
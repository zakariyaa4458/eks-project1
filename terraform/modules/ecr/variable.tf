variable "app_ecr_repo" {
  type        = set(string)
  description = "1 repo for each 9 service"

}


variable "region" {
  type    = string
  default = "eu-west-2"

}

variable "aws_key_ecr_arn" {
  type = string
  
}
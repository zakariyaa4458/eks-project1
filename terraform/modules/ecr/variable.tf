variable "app_ecr_repo" {
  type        = set(string)
  description = "1 repo for each 9 service"

}


variable "region" {
  type    = string
  default = "us-east-1"

}

variable "aws_key_ecr_arn" {
  type = string

}

variable "force_delete" {
  type    = bool
  default = false
}

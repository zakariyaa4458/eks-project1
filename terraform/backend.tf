terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket       = "terraform-state-zakariya-ecs"
    key          = "eks-project1/terraform/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

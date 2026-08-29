terraform {
  backend "s3" {
    bucket       = "terraform-state-zakariya-ecs"
    key          = "eks-project1/terraform/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

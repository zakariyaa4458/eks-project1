terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket       = "REPLACE_WITH_YOUR_TERRAFORM_STATE_BUCKET"
    key          = "eks-project1/terraform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

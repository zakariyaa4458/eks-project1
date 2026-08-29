resource "aws_ecr_repository" "eks-repositories" {
  name     = each.value
  for_each = var.app_ecr_repo
  region   = var.region

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
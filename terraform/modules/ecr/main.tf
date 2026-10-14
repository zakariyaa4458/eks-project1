resource "aws_ecr_repository" "eks-repositories" {
  name         = each.value
  for_each     = var.app_ecr_repo
  region       = var.region
  force_delete = var.force_delete

  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"

    # kms_key = var.aws_key_ecr_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

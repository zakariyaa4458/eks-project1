module "eks" {
  source                                            = "./modules/eks"
  depends_on = [ module.networking, module.iam]
  aws_sg_eks_worker_node                            = module.security.aws_sg_eks_worker_node.id
  aws_private_subnet_ids                            = module.networking.aws_private_subnet_ids
  aws_public_subnet_ids                             = module.networking.aws_public_subnet_ids
  aws_sg_eks_control_plane                          = module.security.aws_sg_eks_control_plane.id
  aws_iam_role_policy_attachment_eks_cluster_policy = module.iam.aws_iam_role_policy_attachment_eks_cluster_policy.id
  aws_iam_role_eks_role                             = module.iam.aws_iam_role_eks_role.id
  aws_iam_role_node_group_role                      = module.iam.aws_iam_role_node_group_role.id

}

module "ecr" {
  source       = "./modules/ecr"
  app_ecr_repo = var.app_ecr_repo
}

module "helm" {
  source                               = "./modules/helm"
  depends_on = [ module.eks ]
  module_karpenter_queue_name          = module.irsa.module_karpenter_queue_name
  karpeneter_module                    = module.irsa.karpeneter_module
  aws_eks_cluster_eks_cluster_endpoint = module.eks.aws_eks_cluster_eks_cluster_endpoint
  aws_eks_cluster_eks_cluster_name     = module.eks.aws_eks_cluster_eks_cluster_name
  module_external_dns                  = module.irsa.module_external_dns
  module_aws_load_balancer_controller  = module.irsa.module_aws_load_balancer_controller

}


module "iam" {
  source = "./modules/iam"

}


module "irsa" {
  source                                           = "./modules/irsa"
  aws_vpc_id                                       = module.networking.aws_vpc_id
  aws_iam_openid_connect_provider_arn              = module.eks.aws_iam_openid_connect_provider_arn
  aws_eks_cluster_eks_cluster_name                 = module.eks.aws_eks_cluster_eks_cluster_name
  aws_eks_cluster_eks_cluster_identity_oidc_issuer = module.eks.aws_eks_cluster_eks_cluster_identity_oidc_issuer
  aws_eks_cluster                                  = module.eks.aws_eks_cluster



}

module "networking" {
  source = "./modules/networking"

}

module "security" {
  source                = "./modules/security"
  aws_vpc_id            = module.networking.aws_vpc_id
  aws_vpc_id_cidr_block = module.networking.aws_vpc_id_cidr_block

}

module "sqs" {
  source = "./modules/sqs"

}
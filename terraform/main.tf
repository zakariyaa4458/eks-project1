module "eks" {
  create_oidc_provider = var.create_iam_resources
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  node_instance_types  = var.node_instance_types
  region               = var.region
  #checkov:skip=CKV_AWS_1: these are local modules 
  source                                            = "./modules/eks"
  depends_on                                        = [module.networking]
  aws_sg_eks_worker_node                            = module.security.aws_sg_eks_worker_node.id
  aws_private_subnet_ids                            = module.networking.aws_private_subnet_ids
  aws_public_subnet_ids                             = module.networking.aws_public_subnet_ids
  aws_sg_eks_control_plane                          = module.security.aws_sg_eks_control_plane.id
  aws_iam_role_policy_attachment_eks_cluster_policy = var.create_iam_resources ? module.iam[0].aws_iam_role_policy_attachment_eks_cluster_policy.id : "existing-policy"
  aws_iam_role_eks_role                             = var.create_iam_resources ? module.iam[0].aws_iam_role_eks_role.arn : var.eks_role_arn
  aws_iam_role_node_group_role                      = var.create_iam_resources ? module.iam[0].aws_iam_role_node_group_role.arn : var.aws_iam_role_node_group_role_arn
  aws_key_arn                                       = var.aws_key_arn
  #ip_address                                        = var.ip_address
  aws_account_id                   = var.aws_account_id
  eks_role_arn                     = var.create_iam_resources ? module.iam[0].aws_iam_role_eks_role.arn : var.eks_role_arn
  aws_iam_role_node_group_role_arn = var.create_iam_resources ? module.iam[0].aws_iam_role_node_group_role.arn : var.aws_iam_role_node_group_role_arn

}

module "ecr" {
  force_delete = var.force_delete_ecr
  region       = var.region
  #checkov:skip=CKV_AWS_1: these are local modules
  source          = "./modules/ecr"
  app_ecr_repo    = var.app_ecr_repo
  aws_key_ecr_arn = var.aws_key_ecr_arn
}

module "helm" {
  count = var.install_platform_helm ? 1 : 0
  #checkov:skip=CKV_AWS_1: these are local modules
  source                               = "./modules/helm"
  depends_on                           = [module.eks]
  module_karpenter_queue_name          = module.irsa[0].module_karpenter_queue_name
  karpeneter_module                    = module.irsa[0].karpeneter_module
  aws_eks_cluster_eks_cluster_endpoint = module.eks.aws_eks_cluster_eks_cluster_endpoint
  aws_eks_cluster_eks_cluster_name     = module.eks.aws_eks_cluster_eks_cluster_name
  module_aws_load_balancer_controller  = module.irsa[0].module_aws_load_balancer_controller
  ebs_csi_controller_role_arn          = module.irsa[0].ebs_csi_controller_role_arn

}


module "iam" {
  count = var.create_iam_resources ? 1 : 0
  #checkov:skip=CKV_AWS_1: these are local modules
  source                                  = "./modules/iam"
  aws_account_id                          = var.aws_account_id
  aws_cloudwatch_log_group_flow_log_group = module.security.aws_cloudwatch_log_group_flow_log_group.arn

}


module "irsa" {
  count  = var.create_iam_resources ? 1 : 0
  region = var.region
  #checkov:skip=CKV_AWS_1: these are local modules
  source                                           = "./modules/irsa"
  aws_vpc_id                                       = module.networking.aws_vpc_id
  aws_iam_openid_connect_provider_arn              = module.eks.aws_iam_openid_connect_provider_arn
  aws_eks_cluster_eks_cluster_name                 = module.eks.aws_eks_cluster_eks_cluster_name
  aws_eks_cluster_eks_cluster_identity_oidc_issuer = module.eks.aws_eks_cluster_eks_cluster_identity_oidc_issuer
  aws_eks_cluster                                  = module.eks.aws_eks_cluster
  eks_oidc_issuer_url                              = module.eks.aws_eks_cluster_eks_cluster_identity_oidc_issuer
  aws_account_id                                   = var.aws_account_id
  postgres_secret_arn                              = var.postgres_secret_arn
  database_secret_arn                              = module.security.database_secret_arn

}

module "networking" {
  region = var.region
  #checkov:skip=CKV_AWS_1: these are local modules
  source = "./modules/networking"

}

module "security" {
  enable_flow_logs = var.enable_flow_logs
  region           = var.region
  #checkov:skip=CKV_AWS_1: these are local modules
  source                              = "./modules/security"
  aws_vpc_id                          = module.networking.aws_vpc_id
  aws_vpc_id_cidr_block               = module.networking.aws_vpc_id_cidr_block
  aws_iam_role_policy_flow_log_policy = var.create_iam_resources ? module.iam[0].aws_iam_role_policy_flow_log_policy.id : "disabled"
  aws_iam_role_flow_log_role          = var.create_iam_resources ? module.iam[0].aws_iam_role_flow_log_role.arn : var.flow_log_role_arn
  cloudwatch_key_arn                  = var.cloudwatch_key_arn
  aws_account_id                      = var.aws_account_id
  flow_log_role_arn                   = var.create_iam_resources ? module.iam[0].aws_iam_role_flow_log_role.arn : var.flow_log_role_arn
  database_url                        = var.database_url


}

module "sqs" {
  region = var.region
  #checkov:skip=CKV_AWS_1: these are local modules
  source = "./modules/sqs"

}

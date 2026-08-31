module "cert_manager_irsa_role" {
  version = "5.60.0"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks?ref=b653d7727a6dc4ad8ba822952bccb7ee812cd4ef"


  role_name                     = "cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z101674438AEID6T19NFK"]

  oidc_providers = {
    eks = {
      provider_arn               = var.aws_iam_openid_connect_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

}


module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter?ref=76524a21b323679f22484ddd98ce0ae90b707464"
  region = var.region
 

  cluster_name = var.aws_eks_cluster

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

module "external-dns" {
  version = "5.60.0"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks?ref=b653d7727a6dc4ad8ba822952bccb7ee812cd4ef"


  role_name                     = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z101674438AEID6T19NFK"]

  oidc_providers = {
    eks = {
      provider_arn               = var.aws_iam_openid_connect_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

}

module "aws-load-balancer-controller" {
  version = "5.0.1"
  source  = "lablabs/eks-load-balancer-controller/aws?ref=8a59a013f90404a9343fb64179078b2796ce3846"



  cluster_name = var.aws_eks_cluster

  cluster_identity_oidc_issuer = var.aws_eks_cluster_eks_cluster_identity_oidc_issuer

  cluster_identity_oidc_issuer_arn = var.aws_iam_openid_connect_provider_arn

  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "kube-system"

  enabled = true

  values = file("helm-values/aws-load-balancer-controller.yaml")

  settings = {
    "vpcId" = var.aws_vpc_id
  }

}
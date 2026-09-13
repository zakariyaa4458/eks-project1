module "cert_manager_irsa_role" {
  #checkov:skip=CKV_AWS_1: 
  version = "5.60.0"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

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
  #checkov:skip=CKV_AWS_1: 
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
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
  #checkov:skip=CKV_AWS_1: 
  version = "5.60.0"
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"


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
  #checkov:skip=CKV_AWS_1: 
  version = "5.0.1"
  source = "lablabs/eks-load-balancer-controller/aws"


  cluster_name = var.aws_eks_cluster

  cluster_identity_oidc_issuer = var.aws_eks_cluster_eks_cluster_identity_oidc_issuer

  cluster_identity_oidc_issuer_arn = var.aws_iam_openid_connect_provider_arn

  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "aws-load-balancer-controller"

  enabled = true

  values = file("helm-values/aws-load-balancer-controller.yaml")

  settings = {
    "vpcId" = var.aws_vpc_id
  }

}

resource "aws_iam_role" "ebs_csi_controller" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = var.aws_iam_openid_connect_provider_arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"

            "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  role       = aws_iam_role.ebs_csi_controller.name
  policy_arn =  "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "worker_iam_role" {
  name = "worker-iam-role"

  assume_role_policy = jsonencode({
   Version = "2012-10-17"

   Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"

        Principal = {
          Federated =  var.aws_iam_openid_connect_provider_arn
        }

        Condition = {
          StringEquals = {
        "oidc.eks.eu-west-2.amazonaws.com/id/507F56E12A4EA46AD10B6AA97B90F722:sub" = "system:serviceaccount:application-namespace:worker-service-account"
        "oidc.eks.eu-west-2.amazonaws.com/id/507F56E12A4EA46AD10B6AA97B90F722:aud" = "sts.amazonaws.com"               
      }, 
        }
      }
    ]

  }
  )
}


data "aws_iam_policy_document" "worker_iam_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:SendMessage"
    ]

    
    resources = ["arn:aws:sqs:eu-west-2:499024813019:eks_sqs"]
  }

}

resource "aws_iam_policy" "worker_iam_policy" {
  name   = "worker-iam-policy"
  policy = data.aws_iam_policy_document.worker_iam_policy_document.json
}


resource "aws_iam_role_policy_attachment" "Worker_iam_policy_attachment" {
  role       = aws_iam_role.worker_iam_role.name
  policy_arn = aws_iam_policy.worker_iam_policy.arn
}




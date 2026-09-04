resource "aws_eks_cluster" "eks-cluster" {
  #checkov:skip=CKV_AWS_39: using home Ip address 
  region   = var.region
  name     = "eks-cluster"
  #role_arn = var.aws_iam_role_eks_role
  role_arn = var.eks_role_arn
  version  = "1.35"

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    provider {
   key_arn = var.aws_key_arn
    }

    resources = ["secrets"]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }


  depends_on = [
    var.aws_iam_role_policy_attachment_eks_cluster_policy
  ]

  vpc_config {

    security_group_ids = [var.aws_sg_eks_control_plane]
    
  

    public_access_cidrs = ["0.0.0.0/0"]
    subnet_ids = [


      var.aws_public_subnet_ids[0],
      var.aws_public_subnet_ids[1],
      var.aws_public_subnet_ids[2]
    ]
  }


}

resource "aws_eks_node_group" "eks-node-group" {
  launch_template {
    name    = aws_launch_template.eks_launch_template.id
    version = aws_launch_template.eks_launch_template.latest_version
  }
  region          = var.region
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = var.aws_iam_role_node_group_role_arn
  #node_role_arn   = var.aws_iam_role_node_group_role 
  subnet_ids = [
    var.aws_private_subnet_ids[0],
    var.aws_private_subnet_ids[1],
    var.aws_private_subnet_ids[2]
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

}

data "tls_certificate" "tls_certificate_eks" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "default" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls_certificate_eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_launch_template" "eks_launch_template" {
  name   = "eks-launch-template"
  region = var.region

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  network_interfaces {
    security_groups = [var.aws_sg_eks_worker_node]

  }


}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.eks-cluster.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [
    aws_eks_node_group.eks-node-group
  ]
}
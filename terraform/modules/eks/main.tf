resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/eks-cluster/cluster"
  retention_in_days = 30
}

resource "aws_eks_cluster" "eks-cluster" {
  depends_on = [aws_cloudwatch_log_group.eks]
  #checkov:skip=CKV_AWS_39: using home Ip address 
  region = var.region
  name   = "eks-cluster"
  #role_arn = var.aws_iam_role_eks_role
  role_arn = var.eks_role_arn
  version  = "1.35"

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  dynamic "encryption_config" {
    for_each = var.aws_key_arn == null ? [] : [var.aws_key_arn]
    content {
      provider { key_arn = encryption_config.value }
      resources = ["secrets"]
    }
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }




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
    id      = aws_launch_template.eks_launch_template.id
    version = aws_launch_template.eks_launch_template.latest_version
  }
  region          = var.region
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "eks-node-group"
  instance_types  = var.node_instance_types
  ami_type        = "AL2023_x86_64_STANDARD"
  node_role_arn   = var.aws_iam_role_node_group_role_arn
  #node_role_arn   = var.aws_iam_role_node_group_role 
  subnet_ids = [
    var.aws_private_subnet_ids[0],
    var.aws_private_subnet_ids[1],
    var.aws_private_subnet_ids[2]
  ]

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

}

data "tls_certificate" "tls_certificate_eks" {
  count = var.create_oidc_provider ? 1 : 0
  url   = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "default" {
  count           = var.create_oidc_provider ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.tls_certificate_eks[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_launch_template" "eks_launch_template" {
  name   = "eks-launch-template"
  region = var.region

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
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

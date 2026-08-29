output "aws_iam_openid_connect_provider_arn" {
    value = aws_iam_openid_connect_provider.default.arn
    description = "aws iam openid connect provider default arn"
  
}

output "aws_eks_cluster_eks_cluster_identity" {
    value = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
    description = "aws eks cluster identity oidc isuuer"
  
}

output "aws_eks_cluster" {
    value = aws_eks_cluster.eks-cluster.name
    description = "aws eks cluster and cluster name (eks_cluster)"
  
}

output "aws_eks_cluster_eks_cluster_identity_oidc_issuer" {
    value = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
  
}

output "aws_eks_cluster_eks_cluster_certificate_authority_data" {
    value = aws_eks_cluster.eks-cluster.certificate_authority[0].data
  
}

output "aws_eks_cluster_eks_cluster_endpoint" {
    value = aws_eks_cluster.eks-cluster.endpoint
  
}

output "aws_eks_cluster_eks_cluster_name" {
    value = aws_eks_cluster.eks-cluster.name
  
}
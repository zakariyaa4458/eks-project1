output "aws_iam_role_policy_attachment_eks_cluster_policy" {
    value = aws_iam_role_policy_attachment.eks_cluster_policy
  
}

output "aws_iam_role_eks_role" {
    value = aws_iam_role.eks-role
  
}

output "aws_iam_role_node_group_role" {
    value = aws_iam_role.node-group-role
  
}

output "aws_iam_role_flow_log_role" {
    value = aws_iam_role.flow_log_role
  
}

output "aws_iam_role_policy_flow_log_policy" {
    value = aws_iam_role_policy.flow_log_policy
  
}


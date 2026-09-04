output "aws_sg_eks_worker_node" {
    value = aws_security_group.Eks-worker-node-sg
  
}

output "aws_sg_eks_control_plane" {
    value = aws_security_group.Eks-control-plane-sg
  
}

output "aws_cloudwatch_log_group_flow_log_group" {
    value = aws_cloudwatch_log_group.flow_log_group
  
}
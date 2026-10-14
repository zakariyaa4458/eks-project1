resource "aws_security_group" "dashboard_nlb" {
  name        = "eks-dashboard-nlb"
  description = "Public dashboard listener"
  vpc_id      = module.networking.aws_vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "dashboard_public" {
  security_group_id = aws_security_group.dashboard_nlb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "dashboard_to_nodes" {
  security_group_id = aws_security_group.dashboard_nlb.id
  cidr_ipv4         = module.networking.aws_vpc_id_cidr_block
  ip_protocol       = "tcp"
  from_port         = 30086
  to_port           = 30086
}

resource "aws_vpc_security_group_ingress_rule" "dashboard_nodeport" {
  security_group_id            = module.security.aws_sg_eks_worker_node.id
  referenced_security_group_id = aws_security_group.dashboard_nlb.id
  ip_protocol                  = "tcp"
  from_port                    = 30086
  to_port                      = 30086
}

resource "aws_lb" "dashboard" {
  depends_on                       = [module.networking]
  name                             = "eks-dashboard"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = module.networking.aws_public_subnet_ids
  security_groups                  = [aws_security_group.dashboard_nlb.id]
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "dashboard" {
  name        = "eks-dashboard"
  port        = 30086
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.networking.aws_vpc_id
  health_check {
    protocol = "HTTP"
    port     = "traffic-port"
    path     = "/livez"
    matcher  = "200"
  }
}

resource "aws_lb_listener" "dashboard" {
  load_balancer_arn = aws_lb.dashboard.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }
}

resource "aws_autoscaling_attachment" "dashboard" {
  autoscaling_group_name = module.eks.node_autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.dashboard.arn
}

output "dashboard_url" {
  value = "http://${aws_lb.dashboard.dns_name}"
}

output "platform_config" {
  value = {
    cluster_name        = module.eks.aws_eks_cluster_eks_cluster_name
    cluster_endpoint    = module.eks.aws_eks_cluster_eks_cluster_endpoint
    cluster_ca          = module.eks.aws_eks_cluster_eks_cluster_certificate_authority_data
    database_secret_arn = module.security.database_secret_arn
    queue_url           = module.sqs.queue_url
    ebs_csi_role_arn    = module.irsa[0].ebs_csi_controller_role_arn
  }
}

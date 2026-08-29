resource "aws_security_group" "Eks-control-plane-sg" {
  name        = "sg for eks control plane"
  description = "Security group for the EKS control plane, allowing secure communication between the cluster control plane and worker nodes"
  vpc_id      = var.aws_vpc_id
  region      = var.region


}

resource "aws_vpc_security_group_ingress_rule" "ingress-control-plane-rule" {
  region            = var.region
  security_group_id = aws_security_group.Eks-control-plane-sg.id
  cidr_ipv4         = var.aws_vpc_id_cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "egress-control-plane-rule" {
  region            = var.region
  security_group_id = aws_security_group.Eks-control-plane-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}




resource "aws_security_group" "Eks-worker-node-sg" {
  region      = var.region
  name        = "sg for worker-nodes"
  description = "Security group for the EKS worker nodes, allowing secure communication between the cluster control plane and other resources"
  vpc_id      = var.aws_vpc_id
 
  tags = {

    "karpenter.sh/discovery" = "eks-cluster"
  }


}

resource "aws_vpc_security_group_ingress_rule" "ingress_worker_node_rule" {
  region            = var.region
  security_group_id = aws_security_group.Eks-worker-node-sg.id
  cidr_ipv4         = var.aws_vpc_id_cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "ingress_worker_node_cluster_rule" {
  region                       = var.region
  security_group_id            = aws_security_group.Eks-worker-node-sg.id
  referenced_security_group_id = aws_security_group.Eks-control-plane-sg.id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
  description                  = "for communication from the control plane"
}


resource "aws_vpc_security_group_egress_rule" "egress_worker_node_rule" {
  region            = var.region
  security_group_id = aws_security_group.Eks-worker-node-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "ingress_worker_to_worker_node_rule" {
  region            = var.region
  referenced_security_group_id = aws_security_group.Eks-worker-node-sg.id
  security_group_id = aws_security_group.Eks-worker-node-sg.id
  ip_protocol = "-1"
  description = "allows communication between worker nodes"
}
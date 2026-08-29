output "aws_vpc_id" {
  value = aws_vpc.main.id
}

output "aws_private_subnet_ids" {
  value = [for subnet in aws_subnet.private-subnet : subnet.id]
}

output "aws_public_subnet_ids" {
  value = [for subnet in aws_subnet.public-eks-subnet : subnet.id]
}

output "aws_vpc_id_cidr_block" {
    value = aws_vpc.main.cidr_block
  
}
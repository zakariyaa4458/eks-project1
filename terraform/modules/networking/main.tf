resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11: it is enabled through and refernced through the vpc variable
  region           = var.region
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main

  
}

resource "aws_subnet" "private-subnet" {

  vpc_id = aws_vpc.main.id
  region = var.region

  map_public_ip_on_launch = "false"


  for_each = {
    "eu-west-2a" = "10.0.4.0/24"
    "eu-west-2b" = "10.0.5.0/24"
    "eu-west-2c" = "10.0.6.0/24"
  }
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name                                = "private-subnet-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery" = "eks-cluster"

  }
}


resource "aws_subnet" "public-eks-subnet" {
  vpc_id                  = aws_vpc.main.id
  region                  = var.region
  map_public_ip_on_launch = false

  for_each = {
    "eu-west-2a" = "10.0.1.0/24"
    "eu-west-2b" = "10.0.2.0/24"
    "eu-west-2c" = "10.0.3.0/24"
  }
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name                       = "eks-subnet-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}


resource "aws_route_table" "private-route-table" {
  region = var.region
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
}

resource "aws_route_table" "public-route-table" {
  region = var.region
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id

  }

}

resource "aws_route_table_association" "private-route-table-association" {
  region         = var.region
  for_each       = aws_subnet.private-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "public-route-table-association" {
  region         = var.region
  for_each       = aws_subnet.public-eks-subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-route-table.id
}


resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public-eks-subnet["eu-west-2a"].id
  region        = var.region

  tags = {
    Name        = "nat-gateway"
    description = "NAT Gateway for private subnets, placed in public subnet eu-west-2a"
  }
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.main.id
  region = var.region

  tags = {
    Name        = "internet-gateway"
    description = "Internet Gateway for the VPC and public subnets"
  }
}


resource "aws_eip" "nat-eip" {
  #checkov:skip=CKV2_AWS_19: This eip is being used

  region = var.region
  tags = {
    Name        = "nat-eip"
    description = "Elastic IP for the NAT Gateway"
  }
}
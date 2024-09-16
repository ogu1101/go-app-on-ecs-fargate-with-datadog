# VPC

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subnets

## Subnets for ALB

resource "aws_subnet" "alb_az_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "alb_az_c" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}c"
}

resource "aws_subnet" "alb_az_d" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}d"
}

## Subnets for ECS

resource "aws_subnet" "ecs_az_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "ecs_az_c" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "${var.region}c"
}

resource "aws_subnet" "ecs_az_d" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.6.0/24"
  availability_zone = "${var.region}d"
}

## Subnets for RDS

resource "aws_subnet" "rds_az_a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.7.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "rds_az_c" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.8.0/24"
  availability_zone = "${var.region}c"
}

resource "aws_subnet" "rds_az_d" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.9.0/24"
  availability_zone = "${var.region}d"
}

## Subnet for NAT Gateway

resource "aws_subnet" "nat_gateway" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.10.0/24"
}

# Security Groups

## Security Group for ALB

resource "aws_security_group" "alb" {
  name        = "${var.env}-security-group-alb"
  description = "Allow HTTP inbound traffic and all outbound traffic to ECS"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.global_ip_address
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id
  ip_protocol                  = "-1" # semantically equivalent to all ports
}

## Security Group for ECS

resource "aws_security_group" "ecs" {
  name        = "${var.env}-security-group-ecs"
  description = "Allow inbound traffic from ALB and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

## Security Group for RDS

resource "aws_security_group" "rds" {
  name        = "${var.env}-security-group-rds"
  description = "Allow inbound traffic from ECS"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_ecs" {
  security_group_id = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

# Internet Gateway

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

# NAT Gateway

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.nat_gateway.id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet_gateway]
}

# EIP

resource "aws_eip" "nat_gateway" {
  domain   = "vpc"
}

# Route Tables

## Route Table for ALB

resource "aws_route_table" "alb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "alb_az_a" {
  subnet_id      = aws_subnet.alb_az_a.id
  route_table_id = aws_route_table.alb.id
}

resource "aws_route_table_association" "alb_az_c" {
  subnet_id      = aws_subnet.alb_az_c.id
  route_table_id = aws_route_table.alb.id
}

resource "aws_route_table_association" "alb_az_d" {
  subnet_id      = aws_subnet.alb_az_d.id
  route_table_id = aws_route_table.alb.id
}

## Route Table for NAT Gateway

resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "nat_gateway" {
  subnet_id      = aws_subnet.nat_gateway.id
  route_table_id = aws_route_table.nat_gateway.id
}

## Route Table for ECS

resource "aws_route_table" "ecs" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "ecs_az_a" {
  subnet_id      = aws_subnet.ecs_az_a.id
  route_table_id = aws_route_table.ecs.id
}

resource "aws_route_table_association" "ecs_az_c" {
  subnet_id      = aws_subnet.ecs_az_c.id
  route_table_id = aws_route_table.ecs.id
}

resource "aws_route_table_association" "ecs_az_d" {
  subnet_id      = aws_subnet.ecs_az_d.id
  route_table_id = aws_route_table.ecs.id
}

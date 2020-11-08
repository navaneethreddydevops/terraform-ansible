resource "aws_vpc" "vpc-master" {
  provider             = aws.region_master
  cidr_block           = var.master_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-jenkins"
  }

}

resource "aws_internet_gateway" "igw-east" {
  provider = aws.region_master
  vpc_id   = aws_vpc.vpc-master.id
  tags = {
    Name = "master-vpc-jenkins"
  }
}

# Data to get all availability zones of VPC for master region
data "aws_availability_zones" "us-east-azs" {
  provider = aws.region_master
  state    = "available"
}

resource "aws_subnet" "subnet_1" {
  provider          = aws.region_master
  availability_zone = element(data.aws_availability_zones.us-east-azs.names, 0)
  vpc_id            = aws_vpc.vpc-master.id
  cidr_block        = "10.0.1.0/24"
}

resource "aws_subnet" "subnet_2" {
  provider          = aws.region_master
  availability_zone = element(data.aws_availability_zones.us-east-azs.names, 1)
  vpc_id            = aws_vpc.vpc-master.id
  cidr_block        = "10.0.2.0/24"
}

resource "aws_vpc" "vpc-worker" {
  provider             = aws.region_worker
  cidr_block           = var.worker_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

resource "aws_internet_gateway" "igw-west" {
  provider = aws.region_worker
  vpc_id   = aws_vpc.vpc-worker.id
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

# Data to get all availability zones of VPC for worker region
data "aws_availability_zones" "us-west-azs" {
  provider = aws.region_worker
  state    = "available"
}

resource "aws_subnet" "subnet_1_west2" {
  provider          = aws.region_worker
  availability_zone = element(data.aws_availability_zones.us-west-azs.names, 0)
  vpc_id            = aws_vpc.vpc-worker.id
  cidr_block        = "192.168.1.0/24"
}
# Peering connection between us-east-1 to us-west-2
resource "aws_vpc_peering_connection" "useast1-uswest2" {
  provider    = aws.region_master
  vpc_id      = aws_vpc.vpc-master.id
  peer_vpc_id = aws_vpc.vpc-worker.id
  peer_region = var.region-worker
}

# VPC Peering acceptor from us-west-2
resource "aws_vpc_peering_connection_accepter" "accept-peering" {
  provider                  = aws.region_worker
  vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  auto_accept               = true
}
# US-EAST Route Table
resource "aws_route_table" "internet-route" {
  provider = aws.region_master
  vpc_id   = aws_vpc.vpc-master.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-east.id
  }
  route {
    cidr_block                = "192.168.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Master-Route-Table"
  }
}

resource "aws_main_route_table_association" "set-master-default-rt-table" {
  provider       = aws.region_master
  vpc_id         = aws_vpc.vpc-master.id
  route_table_id = aws_route_table.internet-route.id
}

# us-west-2 Route Table
resource "aws_route_table" "internet-route-uswest-2" {
  provider = aws.region_worker
  vpc_id   = aws_vpc.vpc-worker.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-west.id
  }
  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.useast1-uswest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Worker-Route-Table"
  }
}
# Main route table association for west vpc
resource "aws_main_route_table_association" "set-worker-default-rt-table" {
  provider       = aws.region_worker
  vpc_id         = aws_vpc.vpc-worker.id
  route_table_id = aws_route_table.internet-route-uswest-2.id
}

# Security Group for Loadbalancer
resource "aws_security_group" "lb-sg" {
  provider    = aws.region_master
  name        = "loadbalancer-sg"
  description = "Allow 443 inbound traffic"
  vpc_id      = aws_vpc.vpc-master.id
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1 # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Jenkins Master
resource "aws_security_group" "jenkins-master-sg" {
  provider    = aws.region_master
  name        = "jenkins-master-sg"
  description = "Allow 443 inbound traffic"
  vpc_id      = aws_vpc.vpc-master.id
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description     = "Allow 8080 from Loadbalancer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb-sg.id]
  }
  ingress {
    description = "Allow traffic from uswest-2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1 # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Jenkins Slave
resource "aws_security_group" "jenkins-slave-sg" {
  provider    = aws.region_worker
  name        = "jenkins-slave-sg"
  description = "Allow 443 inbound traffic"
  vpc_id      = aws_vpc.vpc-worker.id
  ingress {
    description = "Allow 443 from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  ingress {
    description = "Allow traffic from uswest-2"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1 # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}
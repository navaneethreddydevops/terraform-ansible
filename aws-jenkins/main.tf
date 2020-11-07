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
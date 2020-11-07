resource "aws_vpc" "vpc-master" {
  provider             = aws.region_master
  cidr_block           = var.master_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = {
    Name               = "master-vpc-jenkins"
  }

}

resource "aws_vpc" "vpc-worker" {
  provider             = aws.region_worker
  cidr_block           = var.worker_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = {
    Name               = "worker-vpc-jenkins"
  }
}
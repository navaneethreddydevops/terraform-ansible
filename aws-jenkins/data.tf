
# Data to get all availability zones of VPC for master region
data "aws_availability_zones" "us-east-azs" {
  provider = aws.region_master
  state    = "available"
}

# Data to get all availability zones of VPC for worker region
data "aws_availability_zones" "us-west-azs" {
  provider = aws.region_worker
  state    = "available"
}

# GET the latest AMI from parameter store east region
data "aws_ssm_parameter" "linuxAmiEast" {
  provider = aws.region_master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# GET the latest AMI from parameter store for west region
data "aws_ssm_parameter" "linuxAmiWest" {
  provider = aws.region_worker
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
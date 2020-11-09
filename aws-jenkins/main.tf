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

######EC2_iNSTANCE###########
resource "aws_instance" "jenkins-master" {
  provider                    = aws.region_master
  ami                         = data.aws_ssm_parameter.linuxAmiEast.value
  instance_type               = var.instance_type
  key_name                    = var.keypair
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-master-sg.id]
  subnet_id                   = aws_subnet.subnet_1.id
  tags = {
    "Name" = "Jenkins-master-node"
  }
  depends_on = [aws_main_route_table_association.set-master-default-rt-table]
  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-id ${self.id}
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/jenkins-master.yaml
    EOF
  }
}

###WORKER JENKINS EC2 INATANCES ###########
resource "aws_instance" "jenkins-slave" {
  provider                    = aws.region_worker
  count                       = var.number-workers
  ami                         = data.aws_ssm_parameter.linuxAmiWest.value
  instance_type               = var.instance_type
  key_name                    = var.keypair
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-slave-sg.id]
  subnet_id                   = aws_subnet.subnet_1_west2.id
  tags = {
    "Name" = join("-", ["Jenkins-slave-node", count.index + 1])
  }
  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-id ${self.id}
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/jenkins-worker.yaml
    EOF
  }
  depends_on = [aws_main_route_table_association.set-worker-default-rt-table, aws_instance.jenkins-master]
}

#######OUTPUTS##################
output "VPC-US-EAST-1" {
  value = aws_vpc.vpc-master.id
}

output "VPC-US-WEST-2" {
  value = aws_vpc.vpc-worker.id
}

output "VPC-PEERING" {
  value = aws_vpc_peering_connection.useast1-uswest2.id
}

output "LOADBALANCER-SG-ID" {
  value = aws_security_group.lb-sg.id
}

output "JENKINS-MASTER-SG-ID" {
  value = aws_security_group.jenkins-master-sg.id
}

output "JENKINS-SLAVE-SG-ID" {
  value = aws_security_group.jenkins-slave-sg.id
}

output "Jenkins-Master-IP" {
  value = aws_instance.jenkins-master.public_ip
}

output "Jenkins-Slave-IP" {
  value = {
    for instance in aws_instance.jenkins-slave :
    instance.id => instance.public_ip
  }
}
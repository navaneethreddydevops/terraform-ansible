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
    "Name" = "Jenkins-master"
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
    "Name" = join("-", ["Jenkins-slave", count.index + 1])
  }
  provisioner "local-exec" {
    command = <<EOF
aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-id ${self.id}
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/jenkins-worker.yaml
    EOF
  }
  depends_on = [aws_main_route_table_association.set-worker-default-rt-table, aws_instance.jenkins-master]
}

######Application Loadbalancer ########
resource "aws_alb" "jenkins-alb" {
  provider           = aws.region_master
  name               = "jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  tags = {
    Name : "Jenkins-ALB"
  }
}

resource "aws_lb_target_group" "app-lb-tg" {
  provider    = aws.region_master
  name        = "app-lb-tg"
  port        = 8080
  target_type = "instance"
  vpc_id      = aws_vpc.vpc-master.id
  protocol    = "HTTP"
  health_check {
    enabled  = true
    interval = 10
    path     = "/"
    port     = 8080
    protocol = "HTTP"
    matcher  = "200-299"
  }
  tags = {
    Name : "Jenkins-target-group"
  }
}

resource "aws_lb_listener" "jenkins-listner" {
  provider          = aws.region_master
  load_balancer_arn = aws_alb.jenkins-alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-lb-tg.id
  }
}

resource "aws_lb_target_group_attachment" "jenkins-master-attachment" {
  provider         = aws.region_master
  target_group_arn = aws_lb_target_group.app-lb-tg.id
  target_id        = aws_instance.jenkins-master.id
  port             = 8080
}
###########ROUTE53###################
data "aws_route53_zone" "dns" {
  provider = aws.region_master
  name     = var.dns
}
# Creates ACM certificate and requests validation via DNS
resource "aws_acm_certificate" "jenkins-lb-https" {
  provider          = aws.region_master
  domain_name       = join(".", ["jenkins", data.aws_route53_zone.dns.name])
  validation_method = "DNS"
  tags = {
    Name = "Jenkins-ACM"
  }
}
resource "aws_route53_record" "cert_validation" {
  provider = aws.region_master
  for_each = {
    for val in aws_acm_certificate.jenkins-lb-https.domain_validation_options : val.domain_name => {
      name   = val.resource_record_name
      record = val.resource_record_value
      type   = val.resource_record_type
    }
  }
  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.dns.zone_id
}
# Validates the ACM issued certificate via Route53
resource "aws_acm_certificate_validation" "cert"{
  provider=aws.region_master
  certificate_arn = aws_acm_certificate.jenkins-lb-https.arn
  for_each = aws_route53_record.cert_validation
  validation_record_fqdns = [aws_route53_record.cert_validation[each.key].fqdn]
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

output "ALB-DNS-NAME" {
  value = aws_alb.jenkins-alb.dns_name
}
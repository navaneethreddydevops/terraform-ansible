resource "aws_vpc" "vpc-master" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags

}

output "iamuserarn" {
  value = data.aws_iam_user.example
}

output "vpc_cidr" {
  value = concat(aws_vpc.vpc-master.*.id, [""])[0]
}
variable "profile" {
  type = string
  default = "default"
}

variable "region-master" {
  type    = string
  default = "us-east-1"
}

variable "region-worker" {
  type    = string
  default = "us-west-2"
}

variable "shared_credentials_file" {
  type = string
  default = "/Users/navaneethreddy/.aws/credentials"
}

variable "master_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "worker_cidr_block" {
  type    = string
  default = "192.168.0.0/16"
}
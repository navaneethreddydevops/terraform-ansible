variable "region" {
  type = string
}

variable "shared_credentials_file" {
  type = string
}

variable "profile" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "owner" {
  type    = string
  default = "navaneethreddydevops@gmail.com"
}
variable "servicename" {
  type    = string
  default = ""
}
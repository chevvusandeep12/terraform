variable "subnet_id_1" {
  description = "The VPC subnet the instance(s) will be created in"
  default     = "subnet-0eb647b5cd78afa4d"
}

variable "subnet_id_2" {
  description = "The VPC subnet the instance(s) will be created in"
  default     = "subnet-0c2002b886e7d625e"
}

variable "vpc_id" {
  type    = string
  default = "vpc-0dc256aef50afc568"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "image_id" {
  type    = string
  default = "ami-0cf10cdf9fcd62d37" # use the AMI for Amazon Linux 2
}

variable "key_name" {
  type    = string
  default = "sandeepkey"
}

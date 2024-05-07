# Region:
variable "us-west-2" {
  type    = string
  default = "us-west-2"
}

#1: VPC Variable
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

# Subnets 1&2 Variables
variable "subnet1_cidr" {
  type    = string
  default = "10.20.0.0/24"
}

variable "subnet2_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

# AZs Variables: 
variable "az1" {
  type    = string
  default = "us-west-2a"
}

variable "az2" {
  type    = string
  default = "us-west-2b"
}

# ami
variable "ami_id" {
  type    = string
  default = "ami-086f060214da77a16"
}

# Instance App-Server 
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "s3_bucket_salih_devops" {
  type    = string
  default = "salih-s3-bucket"
}

# Database

variable "db_instance_identifier" {
  type    = string
  default = "salih-devops-db"
}
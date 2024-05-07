
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.us-west-2
}

#1: VPC:
resource "aws_vpc" "customVPC" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "Salih-CustomVPC"
  }
}

# IGW :
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.customVPC.id # Creat IGW and attached to the VPC 

  tags = {
    Name = "Salih-IGW"
  }
}
# Route Table: 
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.customVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Salih-PublicRT"
  }
}

# Subnets - 2 Public:
resource "aws_subnet" "custom_public_sunet1" {
  vpc_id                  = aws_vpc.customVPC.id
  cidr_block              = var.subnet1_cidr
  map_public_ip_on_launch = true # indicate that instances launched into the subnet should be assigned a public IP address
  availability_zone       = var.az1
  tags = {
    Name = "Salih-PublicSubnet1"
  }
}

resource "aws_subnet" "custom_public_sunet2" {
  vpc_id                  = aws_vpc.customVPC.id
  cidr_block              = var.subnet2_cidr
  map_public_ip_on_launch = true # indicate that instances launched into the subnet should be assigned a public IP address
  availability_zone       = var.az2

  tags = {
    Name = "Salih-PublicSubnet2"
  }
}

# Route_table_association with the Subnets 
resource "aws_route_table_association" "public_subnet_association1" {
  subnet_id      = aws_subnet.custom_public_sunet1.id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_route_table_association" "public_subnet_association2" {
  subnet_id      = aws_subnet.custom_public_sunet2.id
  route_table_id = aws_route_table.publicRT.id
}

# IAM Role (Assumed by EC2)
resource "aws_iam_role" "test_role" {
  name = "test_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

# IAM Policy for S3 Full Access
resource "aws_iam_policy" "s3_full_access" {
  name        = "s3_full_access_policy"
  description = "Provides full access to S3 resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = "*"
    }]
  })
}


# App-Server 
resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.custom_public_sunet1.id

  tags = {
    Name = "Salih-Terraform"
  }
}

# Security group for EC2 (22, 80 for all)
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.customVPC.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "Salih-Terraform-Project-SG"
  }
}

# ALB with 2 Public Subnets 

resource "aws_lb" "web_alb" {
  name               = "salih-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [aws_subnet.custom_public_sunet1.id, aws_subnet.custom_public_sunet2.id]

  tags = {
    Environment = "Salih-DevOps-Project"
  }
}

# ALB Listener
resource "aws_lb_listener" "web_alb_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"
  

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_server_target_group.arn
  }
}


# ALB Target Group
resource "aws_lb_target_group" "app_server_target_group" {
  name     = "app-server-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.customVPC.id
}


# Launch Template
resource "aws_launch_template" "app_server_template" {
  name_prefix   = "app-server-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AppServerInstance"
    }
  }
}

# SG for RDS allowing port 3306 for all
resource "aws_security_group" "allow_mysql" {
  name        = "allow_mysql"
  description = "Allow MySQL inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.customVPC.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow-MySQL-SG"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "private_bucket" {
  bucket = var.s3_bucket_salih_devops

  tags = {
    Name = "PrivateBucket"
  }
}

# Null resource for retrieving bucket ACL status ( Debugging : Warning: Argument is deprecated )
resource "null_resource" "get_bucket_acl_status" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      acl_status=$(aws s3api get-bucket-acl --bucket ${aws_s3_bucket.private_bucket.bucket} --query "Grants[*].{Permission:Permission,Grantee:Grantee.Type}" | jq -r 'any(.[] | select(.Grantee == "Group" and .Permission == "FULL_CONTROL"))')
      if [ "$acl_status" == "true" ]; then
        echo 'true'
      else
        echo 'false'
      fi
    EOT
  }
}

# Output bucket ACL support status( Debugging : Warning: Argument is deprecated )
output "bucket_acl_support" {
  value = null_resource.get_bucket_acl_status.triggers["always_run"]
}


# Autoscaling Group Launch Template Configuration 
resource "aws_launch_configuration" "app_server_launch_config" {
  name          = "app-server-launch-config"
  image_id      = var.ami_id
  instance_type = var.instance_type


}

# Autoscaling Group with 2 EC2s  
resource "aws_autoscaling_group" "app_server_asg" {
  launch_template {
    id      = aws_launch_template.app_server_template.id
    version = "$Latest"
  }

  min_size            = 2 # Updated to 2 instances
  max_size            = 2 # Updated to 2 instances
  desired_capacity    = 2 # Updated to 2 instances
  vpc_zone_identifier = [aws_subnet.custom_public_sunet1.id, aws_subnet.custom_public_sunet2.id]

  target_group_arns = [aws_lb_target_group.app_server_target_group.arn]

  tag {
    key                 = "Name"
    value               = "AppServerASG"
    propagate_at_launch = true
  }
}

# RDS Subnet Group with 2 Public Subnets
resource "aws_db_subnet_group" "database" {
  name = "my-test-database-subnet-group"
  subnet_ids = [
    aws_subnet.custom_public_sunet1.id,
    aws_subnet.custom_public_sunet2.id
  ]
  tags = {
    Name = "My Test Database Subnet Group"
  }
}

# RDS Instance - MySQL DB Creation
resource "aws_db_instance" "my_database" {
  identifier           = var.db_instance_identifier
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

# RDS Instance - MySQL DB Query 
data "aws_db_instance" "database" {
  db_instance_identifier = aws_db_instance.my_database.identifier
}

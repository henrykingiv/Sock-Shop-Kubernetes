# Sock-Shop-Kubernetes

1. Introduction
1.1. Overview
This documentation provides details on a Terraform module designed to create an Amazon Virtual Private Cloud (VPC). The module encapsulates the AWS VPC resource configuration and includes parameters for customization.

2. Remote Module Structure
2.1. Source Declaration
The module is sourced from the local path "terraform-aws-modules/vpc/aws". Ensure that the module directory structure and files are organized appropriately.

2.2. Module Parameters
The remote module accepts all VPC parameters: Including NAT Gateway and Internet Gateway, some of the accepted parameter are listed below:

2.2.1. vpc_cidr_block
Description: Specifies the CIDR block for the VPC.

Default: "10.0.0.0/16"

2.2.2. tag_vpc
Description: Provides a name for the VPC, incorporating the local name variable.

Default: "${local.name}-vpc"

3. AWS VPC Resource Configuration
3.1. Terraform Resource Block
The AWS VPC is defined through the following Terraform resource block within the remote module:
module "vpc" {
  source              = "terraform-aws-modules/vpc/aws"
  name                = "${local.name}-vpc"
  cidr                = "10.0.0.0/16"
  azs                 = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnet_tags  = { Name = "public-subnet" }
  private_subnet_tags = { Name = "private-subnet" }
  enable_nat_gateway  = true
  single_nat_gateway  = true
  enable_vpn_gateway  = true
  tags = {
    Terraform   = "true"
    Environment = "${local.name}-kubernetes"
  }
}

Jenkins/Introduction
This Terraform code defines an AWS EC2 instance resource of type "aws_instance" named "jenkins-server". The purpose of this instance is to host a Jenkins server in the AWS environment, specifically within the European region ("eu"). The code is part of a modular approach, with the Jenkins-specific configurations organized in a separate module.
resource "aws_instance" "jenkins-server" {
  ami                         = var.ami
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.public-key.id
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.id
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("./jenkins.sh")
  tags = {
    Name = "${local.name}-jenkins"
  }
}

#Create application load balancer
resource "aws_lb" "jenkins-lb" {
  name                       = "jenkins-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.jenkins-sg.id]
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false
  tags = {
    Name = "${local.name}-jenkins-alb"
  }
}

#Create LB Listener for HTTPS
resource "aws_lb_listener" "lbl-https" {
  load_balancer_arn = aws_lb.jenkins-lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.kub8-cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkinslb-tg.arn
  }
}

#Create Target Group
resource "aws_lb_target_group" "jenkinslb-tg" {
  name     = "jenkins-alb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "alb-tg-attachment" {
  target_group_arn = aws_lb_target_group.jenkinslb-tg.arn
  target_id        = aws_instance.jenkins-server.id
  port             = 8080
}

Overview
This Terraform script automates the creation of an AWS ACM (Amazon Certificate Manager) certificate. The script is designed to be modular and customizable, providing a straightforward way to manage SSL/TLS certificates for your domain.

Purpose
The primary purpose of this script is to create an ACM certificate for the specified domain, leveraging the DNS validation method for certificate verification. The create_before_destroy lifecycle configuration ensures a seamless transition during certificate updates or renewals.

Prerequisites
Before using this Terraform script, ensure the following prerequisites are met:

AWS Credentials:

Ensure that you have AWS credentials configured with the necessary permissions for ACM operations.

Terraform Installed:

Install Terraform on your machine. You can download it from the official Terraform website: Terraform Downloads

Variables Setup:

Define the required variables, particularly var.domain-name, representing the domain for which the ACM certificate will be created.

# Import route53 hosted zone from aws account
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

# CREATE A RECORD FOR PRODUCTION ENVIRONMENT
resource "aws_route53_record" "jenkins_A_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.jenkins_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.jenkins-lb.dns_name
    zone_id                = aws_lb.jenkins-lb.zone_id
    evaluate_target_health = true
  }
}

# CREATE CERTIFICATE WHICH IS DEPENDENT ON HAVING A DOMAIN NAME
resource "aws_acm_certificate" "kub8-cert" {
  domain_name               = var.domain_name
  subject_alternative_names = [var.domain_name2]
  validation_method         = "DNS"

  tags = {
    Environment = "production"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ATTACHING ROUTE53 AND THE CERTFIFCATE- CONNECTING ROUTE 53 TO THE CERTIFICATE
resource "aws_route53_record" "kub8-project" {
  for_each = {
    for anybody in aws_acm_certificate.kub8-cert.domain_validation_options : anybody.domain_name => {
      name   = anybody.resource_record_name
      record = anybody.resource_record_value
      type   = anybody.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

# SIGN THE CERTIFICATE
resource "aws_acm_certificate_validation" "sign_cert" {
  certificate_arn         = aws_acm_certificate.kub8-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.kub8-project : record.fqdn]
}

Parameters
ami-redhat: The ID of the Red Hat Amazon Machine Image (AMI) to be used for the Jenkins server instance.

instance_type: The type of the EC2 instance (e.g., t2.medium, m5.large).

subnet_id: The ID of the subnet where the Jenkins server instance will be launched.

jenkins-sg: The security group ID for the Jenkins server, retrieved from the VPC module.

associate_public_ip_address: If set to true, the instance will be assigned a public IP address.

key_name: The name of the EC2 key pair to associate with the instance.

jenkins-name: The tag to identify the Jenkins instance in the AWS environment

#!/bin/bash
sudo apt update -y
sudo apt upgrade -y
sudo apt install git -y
sudo apt install wget -y
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins -y
sudo apt install openjdk-11-jre -y
sudo apt install jenkins -y
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo hostnamectl set-hostname jenkins

# SECURITY GROUP LOAD BALANCER/JENKINS/KUBERNETES
1. Introduction
1.1. Overview
This documentation provides guidance on configuring AWS security groups in Terraform. The code creates security groups for various services, each allowing specific inbound and outbound traffic.

#Create Security group and Rules
resource "aws_security_group" "kub8-sg" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name = "${local.name}-k8s-sg"
  }

}

resource "aws_security_group_rule" "allow-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kub8-sg.id
}

resource "aws_security_group_rule" "allow-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kub8-sg.id
}

#create Security Group for Jenkins
resource "aws_security_group" "jenkins-sg" {
  name        = "jenkins-sg"
  description = "Allow inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP access"
    from_port   = 8080
    to_port     = 8080
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
    Name = "${local.name}-jenkins-sg"
  }
}

#Create security group Load Balancer
resource "aws_security_group" "lb-sg" {
  name        = "lb-sg"
  description = "Allow inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 443
    to_port     = 443
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
    Name = "${local.name}-lb-sg"
  }
}
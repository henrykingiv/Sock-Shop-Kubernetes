#create remote vpc and its component
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnet_tags = {Name = "public-subnet"}
  private_subnet_tags = {Name = "private-subnet"}
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = true
  tags = {
    Terraform = "true"
    Environment = "${local.name}-kubernetes"
  }
}

#RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "jenkins-key.pem"
  file_permission = "600"
}
resource "aws_key_pair" "public-key" {
  key_name   = "jenkins-key2"
  public_key = tls_private_key.keypair.public_key_openssh
}

#Create Security Group and Rules for Kub8
resource "aws_security_group" "kub8-sg" {
  name        = "kub8-sg"
  description = "Allow inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
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
    Name = "${local.name}-kub8-sg"
  }
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

#create IAM policy 
resource "aws_iam_role_policy_attachment" "jenkins_role" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.ec2_role.name
}

#create iam role 
resource "aws_iam_role" "ec2_role" {
  name               = "jenkins-role"
  assume_role_policy = file("${path.root}/jenkins.json")
}

#create IAM INSTANCE PROFILE
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "jenkins-profile"
  role = aws_iam_role.ec2_role.name
}

#Jenkins server for EC2 instance
resource "aws_instance" "jenkins-server" {
    ami = var.ami
    vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
    instance_type = "t2.medium"
    key_name = aws_key_pair.public-key.id
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
    subnet_id = module.vpc.public_subnets[0]
    associate_public_ip_address = true
    user_data = file("./jenkins.sh")
    tags = {
      Name = "${local.name}-jenkins"
    }
}

#Create application load balancer
resource "aws_lb" "jenkins-lb" {
  name               = "jenkins-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins-sg.id]
  subnets            = module.vpc.public_subnets
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
  certificate_arn   = "${aws_acm_certificate.kub8-cert.arn}"
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

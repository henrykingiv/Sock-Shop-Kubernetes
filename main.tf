locals {
  name = "sock-shop-henry"
}
data "aws_vpc" "vpc" {
  id = ""
}
data "aws_subnet" "pubsub01" {
  id = ""
}
data "aws_subnet" "pubsub02" {
  id = ""
}
data "aws_subnet" "pubsub03" {
  id = ""
}
data "aws_subnet" "prvtsub01" {
  id = ""
}
data "aws_subnet" "prvtsub02" {
  id = ""
}
data "aws_subnet" "prvtsub03" {
  id = ""
}
data "aws_security_group" "k8s-sg" {
  id = ""
}
data "aws_acm_certificate" "amazon_issued" {
  domain      = "henrykingroyal.co"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
data "aws_route53_zone" "route53_zone" {
  name         = "henrykingroyal.co"
  private_zone = false
}

module "keypair" {
  source = "./module/keypair"
}

module "ha-proxy" {
  source = "./module/ha-proxy"
  ami = "ami-08e592fbb0f535224"
  ha-proxy-sg = data.aws_security_group.k8s-sg.id
  instance_type = "t3.medium"
  keyname = module.keypair.public-key
  subnet-1 = data.aws_subnet.prvtsub01.id
  master1 = module.master-node.master_private_ip[0]
  master2 = module.master-node.master_private_ip[1]
  master3 = module.master-node.master_private_ip[2]
  tag-ha-proxy1 = "${local.name}-ha-proxy1"
  subnet-2 = data.aws_subnet.prvtsub02.id
  tag-ha-proxy2 = "${local.name}-ha-proxy2"
}

module "bastion-host" {
  source = "./module/bastion-host"
  ami = "ami-08e592fbb0f535224"
  instance_type = "t2.micro"
  keyname = module.keypair.public-key
  subnet-id = data.aws_subnet.pubsub01.id
  private_key = module.keypair.private-key
  tag-bastion = "${local.name}-bastion"
  vpc_id = data.aws_vpc.vpc.id
  tag-Bastion-sg = "${local.name}-bastion-sg"
}

module "master-node" {
  source = "./module/master-node"
  ami = "ami-08e592fbb0f535224"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type = "t3.medium"
  keyname = module.keypair.public-key
  subnet-id = [data.aws_subnet.prvtsub01, data.aws_subnet.prvtsub02, data.aws_subnet.prvtsub03]
  instance_name = "${local.name}-master"
}

module "worker-node" {
  source = "./module/worker-node"
  ami = "ami-08e592fbb0f535224"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type = "t3.medium"
  keyname = module.keypair.public-key
  subnet-id = [data.aws_subnet.prvtsub01, data.aws_subnet.prvtsub02, data.aws_subnet.prvtsub03]
  instance_name = "${local.name}-worker"
}
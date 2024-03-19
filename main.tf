locals {
  name = "sock-shop-henry"
}
data "aws_vpc" "vpc" {
  id = "vpc-0902bfb4a82802be2"
}
data "aws_subnet" "pubsub01" {
  id = "subnet-0d8048a57e3a271fc"
}
data "aws_subnet" "pubsub02" {
  id = "subnet-07bb00e6508c4d685"
}
data "aws_subnet" "pubsub03" {
  id = "subnet-03e757a29a14c15a2"
}
data "aws_subnet" "prvtsub01" {
  id = "subnet-08ff3023bd0fece12"
}
data "aws_subnet" "prvtsub02" {
  id = "subnet-004269e785eeb847a"
}
data "aws_subnet" "prvtsub03" {
  id = "subnet-0e94077d28bf7a218"
}
data "aws_security_group" "k8s-sg" {
  id = "sg-01ac4633d54f339bb"
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
  source        = "./module/ha-proxy"
  ami           = "ami-08e592fbb0f535224"
  ha-proxy-sg   = data.aws_security_group.k8s-sg.id
  instance_type = "t3.medium"
  keyname       = module.keypair.public-key
  subnet-1      = data.aws_subnet.prvtsub01.id
  master1       = module.master-node.master_private_ip[0]
  master2       = module.master-node.master_private_ip[1]
  master3       = module.master-node.master_private_ip[2]
  tag-ha-proxy1 = "${local.name}-ha-proxy1"
  subnet-2      = data.aws_subnet.prvtsub02.id
  tag-ha-proxy2 = "${local.name}-ha-proxy2"
}

module "ansible" {
  source         = "./module/ansible"
  ami            = "ami-08e592fbb0f535224"
  ansible-sg     = data.aws_security_group.k8s-sg.id
  instance_type  = "t2.micro"
  keyname        = module.keypair.public-key
  subnet-id      = data.aws_subnet.prvtsub02.id
  private_key    = module.keypair.private-key
  HAproxy1       = module.ha-proxy.ha-proxy1-pri-ip
  HAproxy2       = module.ha-proxy.ha-proxy2-pri-ip
  master1        = module.master-node.master_private_ip[0]
  master2        = module.master-node.master_private_ip[1]
  master3        = module.master-node.master_private_ip[2]
  worker1        = module.worker-node.worker_private_ip[0]
  worker2        = module.worker-node.worker_private_ip[1]
  worker3        = module.worker-node.worker_private_ip[2]
  tag-ansible    = "${local.name}-ansible"
  bastion_host   = module.bastion-host.bastion_ip
  vpc_id         = data.aws_vpc.vpc.id
  tag-ansible-sg = "${local.name}-ansible-sg"
}

module "bastion-host" {
  source         = "./module/bastion-host"
  ami            = "ami-08e592fbb0f535224"
  instance_type  = "t2.micro"
  keyname        = module.keypair.public-key
  subnet-id      = data.aws_subnet.pubsub01.id
  private_key    = module.keypair.private-key
  tag-bastion    = "${local.name}-bastion"
  vpc_id         = data.aws_vpc.vpc.id
  tag-Bastion-sg = "${local.name}-bastion-sg"
}

module "master-node" {
  source         = "./module/master-node"
  ami            = "ami-08e592fbb0f535224"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type  = "t3.medium"
  keyname        = module.keypair.public-key
  subnet-id      = [data.aws_subnet.prvtsub01.id, data.aws_subnet.prvtsub02.id, data.aws_subnet.prvtsub03.id]
  instance_name  = "${local.name}-master"
}

module "worker-node" {
  source         = "./module/worker-node"
  ami            = "ami-08e592fbb0f535224"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type  = "t3.medium"
  keyname        = module.keypair.public-key
  subnet-id      = [data.aws_subnet.prvtsub01.id, data.aws_subnet.prvtsub02.id, data.aws_subnet.prvtsub03.id]
  instance_name  = "${local.name}-worker"
}

module "promethues" {
  source            = "./module/promethues"
  subnets           = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  prome_sg          = data.aws_security_group.k8s-sg.id
  vpc_id            = data.aws_vpc.vpc.id
  cert_acm          = data.aws_acm_certificate.amazon_issued.arn
  instance          = module.worker-node.workernode-id
  route53_zone_id   = data.aws_route53_zone.route53_zone.zone_id
  prome_domain_name = "promethues.henrykingroyal.co"
}

module "grafana" {
  source              = "./module/grafana"
  subnets             = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  grafana_sg          = data.aws_security_group.k8s-sg.id
  vpc_id              = data.aws_vpc.vpc.id
  cert_acm            = data.aws_acm_certificate.amazon_issued.arn
  instance            = module.worker-node.workernode-id
  route53_zone_id     = data.aws_route53_zone.route53_zone.zone_id
  grafana_domain_name = "grafana.henrykingroyal.co"
}

module "prod-lb" {
  source           = "./module/prod-lb"
  subnets          = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  prod_sg          = data.aws_security_group.k8s-sg.id
  vpc_id           = data.aws_vpc.vpc.id
  prod_cert_acm    = data.aws_acm_certificate.amazon_issued.arn
  instance         = module.worker-node.workernode-id
  route53_zone_id  = data.aws_route53_zone.route53_zone.zone_id
  prod_domain_name = "prod.henrykingroyal.co"
}

module "stage-lb" {
  source            = "./module/stage-lb"
  subnets           = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  stage_sg          = data.aws_security_group.k8s-sg.id
  vpc_id            = data.aws_vpc.vpc.id
  stage_cert_acm    = data.aws_acm_certificate.amazon_issued.arn
  instance          = module.worker-node.workernode-id
  route53_zone_id   = data.aws_route53_zone.route53_zone.zone_id
  stage_domain_name = "stage.henrykingroyal.co"

}
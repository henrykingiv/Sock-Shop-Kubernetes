resource "aws_instance" "ha-proxy-1" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ha-proxy-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-1
  user_data                   = templatefile("./module/ha-proxy/ha-proxy-1.sh", {
    master1 = var.master1
    master2 = var.master2
    master3 = var.master3

  })

  tags = {
    Name = var.tag-ha-proxy1
  }
}

resource "aws_instance" "ha-proxy-2" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ha-proxy-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-2
  user_data                   = templatefile("./module/ha-proxy/ha-proxy-2.sh", {
    master1 = var.master1
    master2 = var.master2
    master3 = var.master3

  })

  tags = {
    Name = var.tag-ha-proxy2
  }
}
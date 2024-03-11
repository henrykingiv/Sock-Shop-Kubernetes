resource "aws_instance" "worker" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.security-group]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  count                       = 3
  subnet_id                   = element(var.subnet-id, count.index)
  user_data                   = <<-EOF
  #!/bin/bash
  sudo hostnamectl set-hostname worker-$(hostname -1)
  EOF

  tags = {
    Name = "${var.instance_name}${count.index}"
  }
}
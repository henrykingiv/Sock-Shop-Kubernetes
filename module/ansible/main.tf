resource "aws_instance" "ansible" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ansible-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-id
  user_data                   = templatefile("./module/ansible/ansible.sh", {
    key = var.private_key,
    haproxy1 = var.HAproxy1,
    haproxy2 = var.HAproxy2,
    master1  = var.master1,
    master2  = var.master2,
    master3  = var.master3,
    worker1  = var.worker1,
    worker2  = var.worker2,
    worker3  = var.worker3
  })

  tags = {
    Name = var.tag-ansible
  }
}

resource "null_resource" "copy-playbook" {
  connection {
    type = "ssh"
    host = aws_instance.ansible.private_ip
    user = "ec2-user"
    private_key = var.private_key
    bastion_host = var.bastion_host
    bastion_user = "ec2-user"
    bastion_private_key = var.private_key
  }
  provisioner "file" {
    source = "./module/ansible/playbook"
    destination = "/home/ec2-user/playbook"
  }
}

resource "aws_security_group" "ansible" {
  name        = "ansible-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

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
    Name = var.tag-ansible-sg
  }
}
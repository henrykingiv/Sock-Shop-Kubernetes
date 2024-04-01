resource "aws_instance" "bastion" {
  ami                         = var.ami
  vpc_security_group_ids      = [aws_security_group.Bastion-sg.id]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-id
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/bastion-script.sh", {
    private_key = var.private_key
  })

  tags = {
    Name = var.tag-bastion
  }
}

# Creating Bastion and Ansible security group
resource "aws_security_group" "Bastion-sg" {
  name        = "Bastion-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.tag-Bastion-sg
  }
}
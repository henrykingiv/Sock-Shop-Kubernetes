output "ansible-server" {
  value = aws_instance.ansible.private_ip
}
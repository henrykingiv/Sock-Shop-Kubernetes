output "master_private_ip" {
  value = aws_instance.master.*.private_ip
}
output "ha-proxy1-pri-ip" {
  value = aws_instance.ha-proxy-1.private_ip
}
output "ha-proxy2-pri-ip" {
  value = aws_instance.ha-proxy-2.private_ip
}
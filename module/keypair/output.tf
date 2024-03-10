output "public-key" {
  value = aws_key_pair.public-key.id
}
output "private-key" {
  value = tls_private_key.keypair.private_key_pem
}
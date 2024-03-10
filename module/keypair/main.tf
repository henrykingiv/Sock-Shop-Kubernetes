#RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "infra-key.pem"
  file_permission = "600"
}
resource "aws_key_pair" "public-key" {
  key_name   = "infra-key"
  public_key = tls_private_key.keypair.public_key_openssh
}
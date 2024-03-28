output "vpc_id" {
  value = module.vpc.vpc_id
}
output "public_subnets1" {
  value = module.vpc.public_subnets[0]
}
output "public_subnets2" {
  value = module.vpc.public_subnets[1]
}
output "public_subnets3" {
  value = module.vpc.public_subnets[2]
}
output "private_subnets1" {
  value = module.vpc.private_subnets[0]
}
output "private_subnets2" {
  value = module.vpc.private_subnets[1]
}
output "private_subnets3" {
  value = module.vpc.private_subnets[2]
}
output "kub8" {
  value = aws_security_group.kub8-sg.id
}
output "jenkins" {
  value = aws_instance.jenkins-server.public_ip
}
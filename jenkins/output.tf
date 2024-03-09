output "vpc_id" {
    value = module.vpc.vpc_id
}
output "public_subnets" {
    value = module.vpc.public_subnets  
}
output "private_subnets" {
    value = module.vpc.private_subnets
}
output "kub8" {
    value = aws_security_group.kub8-sg.id
}
output "jenkins" {
    value = aws_instance.jenkins-server.public_ip
}
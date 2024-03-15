output "ha-proxy1" {
  value = module.ha-proxy.ha-proxy1-pri-ip
}
output "ha-proxy2" {
  value = module.ha-proxy.ha-proxy2-pri-ip
}
output "worker-node" {
  value = module.worker-node.worker_private_ip
}
output "master-node" {
  value = module.master-node.master_private_ip
}
output "ansible" {
  value = module.ansible.ansible-server
}
output "bastion" {
  value = module.bastion-host.bastion_ip
}
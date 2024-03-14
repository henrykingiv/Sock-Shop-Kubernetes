output "worker_private_ip" {
  value = aws_instance.worker.*.private_ip
}
output "workernode-id" {
  value = aws_instance.worker.*.id
}
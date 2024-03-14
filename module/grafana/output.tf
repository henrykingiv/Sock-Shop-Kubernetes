output "grafana_lb_arn" {
  value = aws_lb.grafana_lb.arn
}
output "grafana_lb_tg" {
  value = aws_lb_target_group.grafana-tg.arn
}
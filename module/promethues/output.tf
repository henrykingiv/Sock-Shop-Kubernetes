output "prome_lb_arn" {
  value = aws_lb.prome_lb.arn
}
output "prome_lb_tg" {
  value = aws_lb_target_group.prome-tg.arn
}
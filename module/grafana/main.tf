resource "aws_lb" "grafana_lb" {
  load_balancer_type = "application"
  subnets = var.subnets
  security_groups = [var.grafana_sg]
  enable_deletion_protection = false
  tags = {
    Name = "grafana-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "grafana-tg" {
  name     = "grafana-tg"
  port     = 31300
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 5
    healthy_threshold    = 3
    unhealthy_threshold  = 5  
    path = "/graph"
    
 }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "grafana-http" {
  load_balancer_arn = aws_lb.grafana_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "grafana-https" {
  load_balancer_arn = aws_lb.grafana_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "grafana-tg-attachment" {
  target_group_arn = aws_lb_target_group.grafana-tg.arn
  target_id        = element(split(",", join(",", var.instance)), count.index)
  port             = 31300
  count            = 3
}
#Create Route 53 Record
resource "aws_route53_record" "grafana_record" {
  zone_id = var.route53_zone_id
  name    = var.grafana_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.grafana_lb.dns_name
    zone_id                = aws_lb.grafana_lb.zone_id
    evaluate_target_health = true
  }
}

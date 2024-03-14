resource "aws_lb" "stage_lb" {
  load_balancer_type = "application"
  subnets = (var.subnets)
  security_groups = [var.stage_sg]
  enable_deletion_protection = false
  tags = {
    Name = "stage-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "stage-tg" {
  name     = "stage-tg"
  port     = 30001
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 4
    healthy_threshold    = 3
    unhealthy_threshold  = 3
   }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "stage-http" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "stage-https" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.stage_cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "stage-tg-attachment" {
  target_group_arn = aws_lb_target_group.stage-tg.arn
  target_id        = element(split(",", join(",","${var.instance}")),count.index)
  port             = 30001
  count = 3
}
#Create Route 53 Record
resource "aws_route53_record" "stage_record" {
  zone_id = var.route53_zone_id
  name    = var.stage_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.stage_lb.dns_name
    zone_id                = aws_lb.stage_lb.zone_id
    evaluate_target_health = true
  }
}

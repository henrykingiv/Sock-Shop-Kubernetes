resource "aws_lb" "prome_lb" {
  load_balancer_type = "application"
  subnets = var.subnets
  security_groups = [var.prome_sg]
  enable_deletion_protection = false
  tags = {
    Name = "prome-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "prome-tg" {
  name     = "prome-tg"
  port     = 31090
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
resource "aws_lb_listener" "prome-http" {
  load_balancer_arn = aws_lb.prome_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prome-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "prome-https" {
  load_balancer_arn = aws_lb.prome_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prome-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "prome-tg-attachment" {
  target_group_arn = aws_lb_target_group.prome-tg.arn
  target_id        = element(split(",", join(",", var.instance)), count.index)
  port             = 31090
  count            = 3
}
#Create Route 53 Record
resource "aws_route53_record" "prome_record" {
  zone_id = var.route53_zone_id
  name    = var.prome_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.prome_lb.dns_name
    zone_id                = aws_lb.prome_lb.zone_id
    evaluate_target_health = true
  }
}

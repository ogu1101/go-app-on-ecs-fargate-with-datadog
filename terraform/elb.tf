resource "aws_lb" "alb" {
  name               = "${var.env}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.alb_az_a.id, aws_subnet.alb_az_c.id, aws_subnet.alb_az_d.id]
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.env}-lb-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

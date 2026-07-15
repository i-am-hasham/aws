##############################################################
# Module: ALB (Application Load Balancer)
# Sits in PUBLIC subnets, routes traffic to EC2 in PRIVATE subnets
# Health checks automatically remove unhealthy instances
##############################################################

# ── ALB Security Group ────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB - HTTP and HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── Application Load Balancer ─────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false         # internet-facing
  load_balancer_type = "application" # Layer 7
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids  # must be in PUBLIC subnets

  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-alb" }
}

# ── Target Group ──────────────────────────────────────────────
# Defines where ALB sends traffic and how to health check instances
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2    # 2 consecutive successes = healthy
    unhealthy_threshold = 3    # 3 consecutive failures = unhealthy
    timeout             = 5    # seconds to wait for response
    interval            = 30   # seconds between checks
    path                = "/"  # which URL to check
    matcher             = "200" # expected HTTP status code
  }

  tags = { Name = "${var.project_name}-tg" }
}

# ── Listener ──────────────────────────────────────────────────
# ALB listens on port 80 and forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

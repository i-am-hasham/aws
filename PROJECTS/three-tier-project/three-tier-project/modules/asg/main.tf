##############################################################
# Module: ASG (Auto Scaling Group)
# EC2 instances in PRIVATE app subnets
# Automatically scales based on CPU usage
# Registers/deregisters with ALB target group automatically
##############################################################

# ── Security Group for EC2 instances ─────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "App servers - HTTP only from ALB"
  vpc_id      = var.vpc_id

  # Only accept traffic FROM the ALB security group
  # Direct internet access to EC2 is blocked
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]  # SG-to-SG reference
  }

  ingress {
    description = "SSH for debugging"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

# ── Launch Template ───────────────────────────────────────────
# Blueprint for EC2 instances created by ASG
# Every instance launched by ASG uses this template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.app.id]

  # User data: runs on every new instance launch
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx

    # Show instance metadata on homepage
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

    cat > /var/www/html/index.html << HTML
    <html>
    <body style="font-family: Arial; text-align: center; padding: 50px;">
      <h1>${var.project_name} — 3-Tier Architecture</h1>
      <h2>Instance ID: $INSTANCE_ID</h2>
      <h2>AZ: $AZ</h2>
      <p>Traffic came through: Internet → ALB → EC2 (private subnet) → This page</p>
    </body>
    </html>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-app-instance" }
  }

  lifecycle {
    create_before_destroy = true
    # When launch template changes, create new instances before destroying old ones
    # Prevents downtime during updates
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = var.private_app_subnet_ids  # private subnets
  target_group_arns   = [var.target_group_arn]       # auto-registers with ALB
  health_check_type   = "ELB"                        # use ALB health checks
  health_check_grace_period = 300                    # 5 min for instance to start

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_size

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

# ── Auto Scaling Policies ─────────────────────────────────────
# Scale OUT when CPU > 70% for 2 consecutive periods
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1     # add 1 instance
  cooldown               = 300   # wait 5 min before scaling again
}

# Scale IN when CPU < 30% for 2 consecutive periods
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1    # remove 1 instance
  cooldown               = 300
}

# ── CloudWatch Alarms for Auto Scaling ───────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120   # 2 minutes
  statistic           = "Average"
  threshold           = 70    # 70% CPU
  alarm_description   = "Scale out when CPU > 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30    # 30% CPU
  alarm_description   = "Scale in when CPU < 30%"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

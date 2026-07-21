output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "scale_out_arn" {
  value = aws_autoscaling_policy.scale_out.arn
}

output "scale_in_arn" {
  value = aws_autoscaling_policy.scale_in.arn
}

output "cpu_high_alarm" {
  value = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "cpu_low_alarm" {
  value = aws_cloudwatch_metric_alarm.cpu_low.alarm_name
}
output "alb_dns_name" {
  description = "Open this in browser to access the app"
  value       = module.alb.alb_dns_name
}

output "app_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "db_endpoint" {
  description = "RDS connection endpoint for app servers"
  value       = module.rds.db_endpoint
}

output "asg_name" {
  value = module.asg.asg_name
}

output "sns_topic_arn" {
  description = "Confirm subscription via email before alarms work"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard" {
  value = "https://us-east-1.console.aws.amazon.com/cloudwatch/home#dashboards:name=${module.monitoring.dashboard_name}"
}

output "summary" {
  value = <<-EOT

    ╔══════════════════════════════════════════════════════╗
    ║      3-TIER ARCHITECTURE — DEPLOYED                  ║
    ╠══════════════════════════════════════════════════════╣
    ║  App URL    : http://${module.alb.alb_dns_name}
    ║  DB Host    : ${module.rds.db_endpoint}
    ║  ASG Name   : ${module.asg.asg_name}
    ╠══════════════════════════════════════════════════════╣
    ║  NEXT STEPS:
    ║  1. Confirm SNS email subscription
    ║  2. Open app URL in browser
    ║  3. Check CloudWatch dashboard
    ╚══════════════════════════════════════════════════════╝

  EOT
}

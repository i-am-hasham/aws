##############################################################
# outputs.tf
##############################################################

output "flask_public_ip" {
  description = "Public IP of the Flask EC2 - paste this in browser"
  value       = aws_instance.flask.public_ip
}

output "flask_url" {
  description = "Full URL to access the Flask app"
  value       = "http://${aws_instance.flask.public_ip}:5000"
}

output "ssh_command" {
  description = "SSH command to connect to the EC2"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.flask.public_ip}"
}

output "check_flask_log" {
  description = "Run this on the EC2 to see Flask startup logs"
  value       = "cat /home/ubuntu/flask.log"
}

output "vpc_id" {
  description = "VPC created for this project"
  value       = module.vpc.vpc_id
}

output "summary" {
  description = "Everything you need in one place"
  value = <<-EOT

    ╔══════════════════════════════════════════════════╗
    ║      FLASK APP DEPLOYMENT COMPLETE               ║
    ╠══════════════════════════════════════════════════╣
    ║  Public IP  : ${aws_instance.flask.public_ip}
    ║  Flask URL  : http://${aws_instance.flask.public_ip}:5000
    ║  Health     : http://${aws_instance.flask.public_ip}:5000/health
    ║  Info       : http://${aws_instance.flask.public_ip}:5000/info
    ╠══════════════════════════════════════════════════╣
    ║  SSH        : ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.flask.public_ip}
    ║  Flask Log  : cat /home/ubuntu/flask.log
    ╚══════════════════════════════════════════════════╝

  EOT
}

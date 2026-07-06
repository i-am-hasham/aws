##############################################################
# Module: Security Group (Flask EC2)
#
# Opens 3 ports:
#   22   - SSH from your IP (for file provisioner + remote-exec to work)
#   5000 - Flask app port (for browser access)
#   80   - HTTP (optional, for future nginx reverse proxy)
#
# WHY port 22 must be open:
#   Both provisioners (file and remote-exec) connect over SSH.
#   If port 22 is closed, terraform apply itself fails because
#   Terraform cannot connect to run the provisioner commands.
##############################################################

resource "aws_security_group" "flask" {
  name        = "${var.project_name}-sg"
  description = "Flask EC2 - SSH and Flask app access"
  vpc_id      = var.vpc_id

  # SSH - needed for provisioners AND manual debugging
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Flask app port - anyone can access the app
  ingress {
    description = "Flask app port"
    from_port   = var.flask_port
    to_port     = var.flask_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP - for future nginx reverse proxy setup
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound - EC2 needs internet to download Flask packages
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

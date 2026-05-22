resource "aws_instance" "ec2"{
    ami = var.ami_value
    instance_type = var.instance_type_value
    associate_public_ip_address = true
    tags = {
      Name = var.instance_name
    }
}

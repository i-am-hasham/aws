output "db_endpoint"    { value = aws_db_instance.main.endpoint }
output "db_name"        { value = aws_db_instance.main.db_name }
output "db_port"        { value = aws_db_instance.main.port }
output "rds_sg_id"      { value = aws_security_group.rds.id }
output "db_instance_id" { value = aws_db_instance.main.id }

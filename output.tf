output "rds_endpoint" {
  description = "RDS endpoint name"
  value       = aws_db_instance.default.endpoint
}

output "instance_id" {
  description = "ID of your EC2 instance"
  value = aws_instance.private_ec2.id
}
# Outputs
output "app_url" {
  description = "Public URL to access the deployed HR Management App"
  value       = "http://${aws_lb.app.dns_name}"
}


output "db_endpoint" {
  value = aws_db_instance.hr_db.endpoint
}

output "ssh_command" {
  value = "ssh -i hr-management-key ubuntu@${aws_instance.app_server.public_ip}"
}
output "metabase_url" {
  description = "Open this URL in a browser after the ECS task becomes healthy."
  value       = "http://${aws_lb.this.dns_name}"
}

output "rds_endpoint" {
  description = "Private PostgreSQL endpoint. It is reachable only from the Metabase task security group."
  value       = aws_db_instance.metabase.address
}

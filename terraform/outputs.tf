output "ecr_repository_url" {
  value       = aws_ecr_repository.repository.repository_url
  description = "ECR Repository URL"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "ALB DNS Name"
}

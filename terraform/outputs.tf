output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "ALB DNS Name"
}

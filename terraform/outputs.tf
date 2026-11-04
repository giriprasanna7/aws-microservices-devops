output "ec2_public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IPv4 address for the EC2 host"
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ecr_registry" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "user_repository_url" {
  value = aws_ecr_repository.user.repository_url
}

output "product_repository_url" {
  value = aws_ecr_repository.product.repository_url
}

output "order_repository_url" {
  value = aws_ecr_repository.order.repository_url
}

data "aws_caller_identity" "current" {}

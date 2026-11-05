variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "microservices-devops"
}

variable "instance_type" {
  description = "Choose an instance size suitable for Docker, Prometheus and Grafana; check pricing first"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Existing EC2 key pair name in the selected region"
  type        = string
}

variable "admin_cidr" {
  description = "Your approved public IP in CIDR notation; restrict SSH to this address"
  type        = string
}

variable "monitoring_cidr" {
  description = "CIDR allowed to access Grafana/Prometheus. Prefer your own public IP /32; ports are localhost-bound by Compose as an additional restriction."
  type        = string
}

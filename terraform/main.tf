resource "aws_security_group" "app" {
  name        = "launch-wizard-6"
  description = "launch-wizard-6 created 2026-11-04T10:18:02.573Z"
  vpc_id      = "vpc-0d6afcc29f1515be1"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_ecr_repository" "user" {
  name                 = "user-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "product" {
  name                 = "product-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "order" {
  name                 = "order-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_instance" "app" {
  ami                         = "ami-0c7632fb77f35db43"
  instance_type               = "t3.small"
  subnet_id                   = "subnet-01ab588fa023f33da"
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = "micro-key"
  iam_instance_profile        = "MicroservicesEC2ECRReadRole"
  associate_public_ip_address = true

  user_data_replace_on_change = false

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name = "application"
  }
}

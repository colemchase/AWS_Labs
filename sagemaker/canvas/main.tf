provider "aws" {
  region = "us-east-1"
}

# 1. VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
output "vpc_id" {
  value = aws_vpc.main.id
}


# 2. Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

# 3. IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_execution" {
  name = "sagemaker-canvas-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_full" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 4. SageMaker Domain
resource "aws_sagemaker_domain" "canvas_domain" {
  domain_name = "canvas-lab-domain"
  auth_mode   = "IAM"
  vpc_id      = aws_vpc.main.id
  subnet_ids  = [aws_subnet.private.id]

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn
  }
}

# 5. User Profile for Canvas
resource "aws_sagemaker_user_profile" "canvas_user" {
  domain_id          = aws_sagemaker_domain.canvas_domain.id
  user_profile_name  = "canvas-user"

  user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn
  }
}

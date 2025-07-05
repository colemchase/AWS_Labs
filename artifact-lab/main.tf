provider "aws" {
  region = "us-east-1"
  profile = "chase-sso"
}

# S3 bucket to store artifact
resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "artifact-lab-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-artifact-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "codebuild.amazonaws.com" },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# CodeBuild Project
resource "aws_codebuild_project" "artifact_build" {
  name          = "artifact-lab-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 5
  source {
    type      = "GITHUB"
    location  = "https://github.com/colemchase/AWS.git"
    buildspec = "artifact-lab/buildspec.yml"
  }

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.artifact_bucket.bucket
    packaging = "ZIP"
    path      = "artifact-lab"
    name      = "function.zip"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function from S3 artifact
resource "aws_lambda_function" "artifact_lambda" {
  function_name = "artifactLabFunction"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.9"
  handler       = "lambda_function.handler"
  timeout       = 10

  s3_bucket = aws_s3_bucket.artifact_bucket.bucket
  s3_key    = "artifact-lab/function.zip"
}

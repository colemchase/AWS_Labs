provider "aws" {
  region  = "us-east-1"
  profile = "chase-sso"
}

# S3 bucket to store artifact
resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "artifact-lab-8858"
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

resource "aws_iam_role_policy" "codebuild_s3_policy" {
  name = "codebuild-s3-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::artifact-lab-8858",
          "arn:aws:s3:::artifact-lab-8858/*"
        ]
      }
    ]
  })
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
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }
}

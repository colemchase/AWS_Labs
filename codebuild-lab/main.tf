provider "aws" {
  region = "us-east-1"
  profile = "chase-sso"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_codebuild_project" "this" {
  name          = "codebuild-lab"
  description   = "Build Node.js project from GitHub"
  build_timeout = 5
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
  compute_type                = "BUILD_GENERAL1_SMALL"
  image                       = "aws/codebuild/standard:6.0"
  image_pull_credentials_type = "CODEBUILD"
  type                        = "LINUX_CONTAINER"
  privileged_mode             = false
}


    source {
    type      = "GITHUB"
    location  = "https://github.com/colemchase/AWS.git"
    buildspec = "buildspec.yml"
    }
}

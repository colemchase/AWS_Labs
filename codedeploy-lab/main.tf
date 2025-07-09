provider "aws" {
  region  = "us-east-1"
  profile = "chase-sso"
}

# S3 bucket to store artifact
resource "aws_s3_bucket" "codedeploy_lab_bucket" {
  bucket = "codedeploy-lab-8858"
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-artifact-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach CodeBuild and CloudWatch policies
resource "aws_iam_role_policy_attachment" "codebuild_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "logs_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# CodeBuild Project
resource "aws_codebuild_project" "artifact_build" {
  name          = "codedeploy-lab-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 5

  source {
    type      = "GITHUB"
    location  = "https://github.com/colemchase/AWS.git"
    buildspec = "codedeploy-lab/buildspec.yml"
  }

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.codedeploy_lab_bucket.bucket
    packaging = "ZIP"
    path      = "codedeploy-lab"
    name      = "function.zip"
  }

  environment {
  compute_type                = "BUILD_GENERAL1_SMALL"
  image                       = "aws/codebuild/standard:7.0"
  type                        = "LINUX_CONTAINER"
  privileged_mode             = false
  }
}


# LAMBDA
resource "aws_codedeploy_app" "lambda_app" {
  name = "codedeploy-lambda-app"
  compute_platform = "Lambda"
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_codedeploy_deployment_group" "lambda_group" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "codedeploy-lambda-dg"
  service_role_arn      = aws_iam_role.lambda_exec.arn

  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  deployment_style {
    deployment_type = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

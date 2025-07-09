provider "aws" {
  region  = "us-east-1"
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
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_s3_access" {
  name = "codebuild-s3-upload"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.codedeploy_lab_bucket.arn,
          "${aws_s3_bucket.codedeploy_lab_bucket.arn}/*"
        ]
      }
    ]
  })
}

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
    name      = "function.zip"
  }

  environment {
    compute_type      = "BUILD_GENERAL1_SMALL"
    image             = "aws/codebuild/standard:7.0"
    type              = "LINUX_CONTAINER"
    privileged_mode   = false
  }
}

resource "aws_iam_role_policy" "codebuild_lambda_access" {
  name = "codebuild-lambda-access"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "lambda:GetFunction",
        "lambda:ListVersionsByFunction"
      ],
      Resource = "arn:aws:lambda:us-east-1:940797399432:function:codedeploy-lab-function"
    }]
  })
}


# Lambda execution role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
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

# CodeDeploy Role

resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codedeploy.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codedeploy_s3_access" {
  name = "codedeploy-s3-access"
  role = aws_iam_role.codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      Resource = [
        "${aws_s3_bucket.codedeploy_lab_bucket.arn}/*"
      ]
    }]
  })
}


resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

# CodeDeploy Application
resource "aws_codedeploy_app" "lambda_app" {
  name             = "codedeploy-lambda-app"
  compute_platform = "Lambda"
}

# Deployment Group (no traffic shifting!)
resource "aws_codedeploy_deployment_group" "lambda_group" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "codedeploy-lambda-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  deployment_style {
  deployment_type   = "BLUE_GREEN"
  deployment_option = "WITH_TRAFFIC_CONTROL"
  }


  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# ------------------------------------------
# 🚫 STEP 1: COMMENTED OUT until build runs
# Push to GitHub → Let CodeBuild create function.zip in S3
# Then uncomment these blocks and run `terraform apply` again
# ------------------------------------------

# resource "aws_lambda_function" "lab_function" {
#   function_name = "codedeploy-lab-function"
#   role          = aws_iam_role.lambda_exec.arn
#   handler       = "app.lambda_handler"
#   runtime       = "python3.11"
#   s3_bucket     = aws_s3_bucket.codedeploy_lab_bucket.bucket
#   s3_key        = "function.zip"
#   publish       = true
# }

# resource "aws_lambda_alias" "live" {
#   name             = "live"
#   function_name    = aws_lambda_function.lab_function.function_name
#   function_version = aws_lambda_function.lab_function.version
# }



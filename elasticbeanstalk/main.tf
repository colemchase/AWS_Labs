# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Generate a random suffix for the S3 bucket to ensure uniqueness
resource "random_id" "bucket_id" {
  byte_length = 4
}

# Create S3 bucket to store build artifacts
resource "aws_s3_bucket" "eb_app" {
  bucket        = "eb-app-bucket-${random_id.bucket_id.hex}"
  force_destroy = true  # Allow Terraform to delete all objects when destroying
}

# -----------------------------------------------------------------------------
# IAM Role and Permissions for CodeBuild
# -----------------------------------------------------------------------------

# Create an IAM role that CodeBuild will assume\ n
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach basic build permissions
resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# Enable CloudWatch logging
resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Allow CodeBuild to upload artifacts to S3
resource "aws_iam_role_policy_attachment" "codebuild_s3" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# -----------------------------------------------------------------------------
# CodeBuild Project to compile and package the WAR
# -----------------------------------------------------------------------------

resource "aws_codebuild_project" "war_build" {
  name          = "war-builder"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  # Source: GitHub repository and buildspec path
  source {
    type            = "GITHUB"
    location        = "https://github.com/colemchase/AWS_Labs.git"
    buildspec       = "elasticbeanstalk/demo/buildspec.yml"
    git_clone_depth = 1
  }

  # Artifacts: output the WAR file directly under artifacts/sample.war
  artifacts {
    type           = "S3"
    location       = aws_s3_bucket.eb_app.bucket
    path           = "artifacts"
    namespace_type = "NONE"
    packaging      = "NONE"
  }

  # Build environment settings
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  # Enable CloudWatch logging for build output
  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/war-builder"
      stream_name = "war-builder-stream"
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Role & Instance Profile for Elastic Beanstalk EC2 Instances
# -----------------------------------------------------------------------------

# Create an IAM role for EB EC2 instances\ n
resource "aws_iam_role" "eb_instance_role" {
  name = "aws-elasticbeanstalk-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach the web-tier policy for EC2 instances
resource "aws_iam_role_policy_attachment" "eb_instance_policy" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

# Create an instance profile for EB environment
resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = aws_iam_role.eb_instance_role.name
  role = aws_iam_role.eb_instance_role.name
}

# -----------------------------------------------------------------------------
# Elastic Beanstalk Application and Environment
# -----------------------------------------------------------------------------

# Define the Elastic Beanstalk application container
resource "aws_elastic_beanstalk_application" "tomcat_app" {
  name        = "tomcat-app"
  description = "Tomcat app on Elastic Beanstalk"
}

# Create an application version pointing to the WAR in S3
resource "aws_elastic_beanstalk_application_version" "app_version" {
  name        = "v1"
  application = aws_elastic_beanstalk_application.tomcat_app.name
  bucket      = aws_s3_bucket.eb_app.bucket
  key         = "artifacts/war-builder/sample.war"

  lifecycle {
    create_before_destroy = true
  }
}

# Launch an Elastic Beanstalk environment using the specified application version
resource "aws_elastic_beanstalk_environment" "tomcat_env" {
  name                = "tomcat-env"
  application         = aws_elastic_beanstalk_application.tomcat_app.name
  version_label       = aws_elastic_beanstalk_application_version.app_version.name
  solution_stack_name = "64bit Amazon Linux 2 v4.9.0 running Tomcat 9 Corretto 11"

  # Autoscaling settings: min and max instance counts
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  # Instance profile assignment
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  # Instance type setting
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  # Environment type (load balanced vs. single instance)
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
}

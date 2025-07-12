provider "aws" {
  region = "us-east-1"
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "eb_app" {
  bucket = "eb-app-bucket-${random_id.bucket_id.hex}"
  force_destroy = true
}

# resource "aws_elastic_beanstalk_application" "tomcat_app" {
#   name        = "tomcat-app"
#   description = "Tomcat app on Elastic Beanstalk"
# }

# resource "aws_elastic_beanstalk_application_version" "app_version" {
#   name        = "v1"
#   application = aws_elastic_beanstalk_application.tomcat_app.name
#   bucket      = aws_s3_bucket.eb_app.bucket
#   key         = "artifacts/sample.war"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_elastic_beanstalk_environment" "tomcat_env" {
#   name                = "tomcat-env"
#   application         = aws_elastic_beanstalk_application.tomcat_app.name
#   version_label       = aws_elastic_beanstalk_application_version.app_version.name
#   solution_stack_name = "64bit Amazon Linux 2 v4.9.0 running Tomcat 9 Corretto 11"

#   setting {
#     namespace = "aws:autoscaling:asg"
#     name      = "MinSize"
#     value     = "1"
#   }

#   setting {
#     namespace = "aws:autoscaling:asg"
#     name      = "MaxSize"
#     value     = "2"
#   }

#   setting {
#     namespace = "aws:autoscaling:launchconfiguration"
#     name      = "InstanceType"
#     value     = "t3.micro"
#   }

#   setting {
#     namespace = "aws:elasticbeanstalk:environment"
#     name      = "EnvironmentType"
#     value     = "LoadBalanced"
#   }
# }

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_logs" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_codebuild_project" "war_build" {
  name          = "war-builder"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  source {
    type            = "GITHUB"
    location        = "https://github.com/colemchase/AWS_Labs.git"
    buildspec       = "elasticbeanstalk/demo/buildspec.yml"
    git_clone_depth = 1
  }

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.eb_app.bucket
    path      = "artifacts"
    name      = "sample.war"
    packaging = "NONE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEBUILD_SRC_DIR"
      value = "elasticbeanstalk/demo"
    }
  }

  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/war-builder"
      stream_name = "war-builder-stream"
    }
  }
}

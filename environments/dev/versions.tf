terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2         = "http://localhost:4566"
    iam         = "http://localhost:4566"
    s3          = "http://localhost:4566"
    sts         = "http://localhost:4566"
    route53     = "http://localhost:4566"
    cloudwatch  = "http://localhost:4566"
    autoscaling = "http://localhost:4566"
    elbv2       = "http://localhost:4566"
    rds         = "http://localhost:4566"
  }
}
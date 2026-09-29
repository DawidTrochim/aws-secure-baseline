terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The AWS provider. It uses my local "portfolio" profile, so no keys are stored in this repo.
# default_tags puts the Project tag on every resource that supports tags.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project = "aws-secure-baseline"
    }
  }
}

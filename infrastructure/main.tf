terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.90.0"
    }
  }

  backend "s3" {
    bucket = "92841c5e92997d994f1e144de376b3d3"
    region = "eu-central-1"
    key    = "tfstate"
  }
}

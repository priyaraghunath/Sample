terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-2"  
}

resource "aws_instance" "example_server" {
  ami           = "ami-0418306302097dbff" 
  instance_type = "t2.micro"

  tags = {
    Name = "E-comInstance"
  }
}

resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-ecomwebsite-bucket-name-20250609" 
  acl    = "private"

  tags = {
    Name        = "ExampleS3Bucket"
    Environment = "Production"
  }
}

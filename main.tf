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

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for S3 access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::my-ecomwebsite-bucket-name-20250609",
      "arn:aws:s3:::my-ecomwebsite-bucket-name-20250609/*"
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "ec2_s3_full_access"
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_attach_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "example_server" {
  ami                  = "ami-0418306302097dbff"  # Replace with valid AMI ID for your region
  instance_type        = "t2.micro"

  tags = {
    Name = "E-comInstance"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-ecomwebsite-bucket-name-20250609"  
  acl    = "private"

  tags = {
    Name        = "ExampleS3Bucket"
  }
}

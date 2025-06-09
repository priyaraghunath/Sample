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
  region = "us-west-2" 
}

# S3 Bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-ecomweb-bucket-name-20250609" 
  tags = {
    Name        = "ExampleS3Bucket"
    Environment = "Production"
  }
}

# S3 Bucket ACL (recommended way)
resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.example_bucket.id
  acl    = "private"
}

# S3 Bucket Policy (public read access to all objects)
resource "aws_s3_bucket_policy" "example_bucket_policy" {
  bucket = aws_s3_bucket.example_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}/*"
      }
    ]
  })
}

# IAM Role for EC2 to access S3 (optional, but best practice)
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

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}/*"
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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "example_server" {
  ami                  = "ami-0418306302097dbff" # Replace with a valid AMI for your region
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "ExampleInstance"
  }
}

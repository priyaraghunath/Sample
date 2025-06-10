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

# Random ID for unique suffix
resource "random_id" "suffix" {
  byte_length = 4
}

# Create S3 Bucket with unique name
resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-ecomweb-bucket-${random_id.suffix.hex}"

  tags = {
    Name        = "ExampleS3Bucket"
    Environment = "Production"
  }
}

# Allow public policy on S3 bucket
resource "aws_s3_bucket_public_access_block" "allow_public_policy" {
  bucket                  = aws_s3_bucket.example_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false

  depends_on = [aws_s3_bucket.example_bucket]
}

# Public access policy
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

  depends_on = [aws_s3_bucket_public_access_block.allow_public_policy]
}

# IAM Role with dynamic name
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role_${random_id.suffix.hex}"

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

# IAM Policy document for S3 access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}/*"
    ]
  }
}

# Create IAM policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name   = "ec2_s3_full_access_${random_id.suffix.hex}"
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ec2_attach_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile_${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# Launch EC2 instance with S3 role
resource "aws_instance" "example_server" {
  ami                  = "ami-0418306302097dbff" # us-west-2 Amazon Linux 2 AMI
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "E-comwebInstance"
  }
}

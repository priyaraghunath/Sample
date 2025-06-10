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

# Random suffix for bucket and IAM role names to avoid conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

# Create a unique S3 bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-unique-bucket-${random_id.suffix.hex}"
}

# Allow public access policy (if you want public-read)
resource "aws_s3_bucket_public_access_block" "allow_public_policy" {
  bucket                  = aws_s3_bucket.example_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false

  depends_on = [aws_s3_bucket.example_bucket]
}

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

# IAM Role for EC2
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

# S3 access policy document
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.example_bucket.bucket}/*"
    ]
  }
}

# Attach policy to IAM role
resource "aws_iam_policy" "s3_access" {
  name   = "ec2_s3_full_access_${random_id.suffix.hex}"
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_attach_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_instance_profile_${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# Use default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Launch EC2 instance
resource "aws_instance" "example_server" {
  ami                    = "ami-0418306302097dbff" # Update if needed
  instance_type          = "t2.micro"
  subnet_id              = tolist(data.aws_subnet_ids.default.ids)[0]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
}

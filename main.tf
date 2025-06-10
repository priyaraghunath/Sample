provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-ecom-bucket-name-20250609"
  tags = {
    Name        = "ExampleS3Bucket"
    Environment = "Production"
  }
}

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

resource "aws_instance" "example_server" {
  ami                  = "ami-0418306302097dbff" # Replace with a valid AMI for us-west-2
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "EcomInstance"
  }
}

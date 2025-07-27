provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "demo" {
  bucket        = "tf-force-delete-demo-bucket-${random_id.suffix.hex}"
  force_destroy = true  # <- THIS is what empties the bucket on deletion
}

resource "random_id" "suffix" {
  byte_length = 4
}

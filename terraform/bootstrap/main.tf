provider "aws" {
    region = "ap-northeast-2"
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "cloud-blog-tfstate-139826823260"

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id

    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_dynamodb_table" "terraform_lock" {
    name            = "cloud-blog-state-lock"
    billing_mode    = "PAY_PER_REQUEST"
    hash_key        = "LockID"

    attribute {
    name            = "LockID"
    type            = "S"
    }
}
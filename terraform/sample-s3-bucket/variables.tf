variable "aws_region" {
  default = "us-east-1"
  type = string
}

variable "aws_access_key_id" {
  type = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type = string
  sensitive = true
}

variable "bucket_name" {
  default = "test-bucket"
  type = string
}
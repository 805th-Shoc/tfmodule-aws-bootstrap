#
# Terraform state bucket
#

locals {
  state_bucket   = "${var.account_alias}-${var.bucket_purpose}-${var.region}"
  logging_bucket = "${var.account_alias}-${var.bucket_purpose}-${var.log_name}-${var.region}"
}

resource "aws_iam_account_alias" "alias" {
  count         = var.manage_account_alias ? 1 : 0
  account_alias = var.account_alias
}

module "terraform_state_bucket" {
  source  = "git::https://github.com/805th-Shoc/tfmodule-aws-s3-private-bucket.git"

  bucket         = local.state_bucket
  logging_bucket = local.logging_bucket

  use_account_alias_prefix = false

  enable_s3_public_access_block = var.enable_s3_public_access_block
  tags                          = var.state_bucket_tags

  depends_on = [
    module.terraform_state_bucket_logs
  ]
}

#
# Terraform state bucket logging
#

module "terraform_state_bucket_logs" {
  source  = "git::https://github.com/805th-Shoc/tfmodule-aws-logs.git"

  s3_bucket_name          = local.logging_bucket
  default_allow           = false
  s3_log_bucket_retention = var.log_retention
  versioning_status       = var.log_bucket_versioning

  tags = var.log_bucket_tags
}

#
# Terraform state locking
#

# Ignore warnings about point-in-time recovery since this table holds no data
# The terraform state lock is meant to be ephemeral and does not need recovery
#tfsec:ignore:AWS086
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.dynamodb_table_name
  hash_key       = "LockID"
  read_capacity  = 2
  write_capacity = 2

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.dynamodb_point_in_time_recovery
  }

  tags = var.dynamodb_table_tags
}

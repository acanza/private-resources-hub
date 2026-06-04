# ------------------------------------------------------------------------------
# Module: data_dynamodb
#
# Provisions a single DynamoDB table using a single-table design pattern.
# The table stores both resource metadata and user-to-resource access records,
# separated by pk/sk key prefixes at the application level.
#
# Key design decisions:
# - Single-table model: one table, multiple entity types via pk/sk prefixes.
# - PAY_PER_REQUEST by default: no capacity planning needed for MVP.
# - Point-in-time recovery enabled: allows rollback up to 35 days.
# - Server-side encryption with AWS-owned key (default): meets encryption-at-rest
#   requirement without extra key management overhead in MVP.
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "main" {
  name         = local.table_name
  billing_mode = var.billing_mode

  # --------------------------------------------------------------------------
  # Primary key — single-table design.
  # pk and sk are string attributes used as key prefixes by the application.
  # Example patterns:
  #   pk = "USER#<user_id>"   sk = "RESOURCE#<resource_id>"  → access record
  #   pk = "RESOURCE#<id>"    sk = "METADATA"                 → resource metadata
  # --------------------------------------------------------------------------
  hash_key  = "pk"
  range_key = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  # --------------------------------------------------------------------------
  # Point-in-time recovery — required by security spec.
  # Allows restoring the table to any second within the last 35 days.
  # --------------------------------------------------------------------------
  point_in_time_recovery {
    enabled = true
  }

  # --------------------------------------------------------------------------
  # Server-side encryption — required by security spec.
  # enabled = false uses the AWS-owned CMK (free, no KMS charges).
  # Set enabled = true and provide kms_key_arn to use a customer-managed key.
  # --------------------------------------------------------------------------
  server_side_encryption {
    enabled = false
  }

  tags = var.tags
}

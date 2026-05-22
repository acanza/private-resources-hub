# ------------------------------------------------------------------------------
# Module: data_dynamodb — Locals
# ------------------------------------------------------------------------------

locals {
  table_name = "${var.project_name}-${var.environment}-resource-access"
}

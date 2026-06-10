# ==============================================================================
# Module: github_actions_iam — Local Values
#
# Computed values used internally by this module.
# ==============================================================================

locals {
  role_name = "${var.project_name}-${var.environment}-github-actions"

  common_tags = merge(
    var.tags,
    {
      Module = "github_actions_iam"
    }
  )
}

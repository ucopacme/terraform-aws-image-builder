resource "aws_imagebuilder_lifecycle_policy" "this" {
  count = var.ami_retention_count != null ? 1 : 0

  name           = var.name
  description    = "Retain last ${var.ami_retention_count} AMIs for ${var.name}"
  execution_role = var.lifecycle_execution_role_arn
  resource_type  = "AMI_IMAGE"

  policy_detail {
    action {
      type = "DELETE"
      include_resources {
        amis      = true
        snapshots = true
      }
    }
    filter {
      type  = "COUNT"
      value = var.ami_retention_count
    }
  }

  resource_selection {
    recipe {
      name             = aws_imagebuilder_image_recipe.this.name
      semantic_version = "x.x.x"
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.lifecycle_execution_role_arn != null
      error_message = "lifecycle_execution_role_arn is required when ami_retention_count is set."
    }
  }
}

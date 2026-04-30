resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = var.name
  description                      = var.description
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = var.infrastructure_configuration_arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn
  status                           = var.enabled ? "ENABLED" : "DISABLED"

  image_tests_configuration {
    image_tests_enabled = var.image_tests_enabled
    timeout_minutes     = var.image_tests_timeout
  }

  image_scanning_configuration {
    image_scanning_enabled = var.image_scanning_enabled
  }

  dynamic "schedule" {
    for_each = var.schedule_expression != null ? [1] : []
    content {
      schedule_expression                = var.schedule_expression
      pipeline_execution_start_condition = var.schedule_condition
    }
  }

  tags = var.tags
}

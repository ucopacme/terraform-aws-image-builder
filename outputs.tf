data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

output "pipeline_arn" {
  description = "ARN of the image pipeline"
  value       = aws_imagebuilder_image_pipeline.this.arn
}

output "recipe_arn" {
  description = "ARN of the image recipe (specific version)"
  value       = aws_imagebuilder_image_recipe.this.arn
}

output "distribution_arn" {
  description = "ARN of the distribution configuration"
  value       = aws_imagebuilder_distribution_configuration.this.arn
}

output "image_arn" {
  description = "Image ARN with x.x.x wildcard for use as parent_image in downstream pipelines"
  value       = "arn:aws:imagebuilder:${data.aws_region.this.id}:${data.aws_caller_identity.this.account_id}:image/${var.name}/x.x.x"
}

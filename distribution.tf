resource "aws_imagebuilder_distribution_configuration" "this" {
  name = var.name

  dynamic "distribution" {
    for_each = var.distribution_regions
    content {
      region = distribution.value.region

      ami_distribution_configuration {
        name       = distribution.value.ami_name
        kms_key_id = distribution.value.kms_key_id
        ami_tags   = merge(var.tags, distribution.value.ami_tags)

        dynamic "launch_permission" {
          for_each = length(distribution.value.account_ids) > 0 ? [1] : []
          content {
            user_ids = distribution.value.account_ids
          }
        }
      }
    }
  }

  tags = var.tags
}

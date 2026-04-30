resource "time_static" "recipe_version" {
  triggers = {
    parent_image = var.parent_image
    components   = jsonencode(local.component_arns)
    ebs          = jsonencode(var.ebs_root_volume)
  }
}

resource "aws_imagebuilder_image_recipe" "this" {
  name              = var.name
  version           = "1.0.${floor(time_static.recipe_version.unix / 100)}"
  parent_image      = var.parent_image
  working_directory = var.working_directory

  dynamic "component" {
    for_each = local.component_arns
    content {
      component_arn = component.value
    }
  }

  dynamic "block_device_mapping" {
    for_each = var.ebs_root_volume != null ? [var.ebs_root_volume] : []
    content {
      device_name = block_device_mapping.value.device_name
      ebs {
        volume_size           = block_device_mapping.value.volume_size
        volume_type           = block_device_mapping.value.volume_type
        iops                  = block_device_mapping.value.iops
        throughput            = block_device_mapping.value.throughput
        kms_key_id            = block_device_mapping.value.kms_key_id
        encrypted             = block_device_mapping.value.encrypted
        delete_on_termination = block_device_mapping.value.delete_on_termination
      }
    }
  }

  systems_manager_agent {
    uninstall_after_build = var.uninstall_ssm_agent
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

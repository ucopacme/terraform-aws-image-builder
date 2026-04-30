locals {
  inline_components = {
    for c in var.components : c.name => c if c.data != null
  }
}

resource "time_static" "component_version" {
  for_each = local.inline_components

  triggers = {
    data = sha256(each.value.data)
  }
}

resource "aws_imagebuilder_component" "this" {
  for_each = local.inline_components

  name         = each.key
  version      = "1.0.${floor(time_static.component_version[each.key].unix / 100)}"
  platform     = var.platform
  data         = each.value.data
  skip_destroy = true
  tags         = var.tags
}

locals {
  component_arns = [
    for c in var.components :
    c.arn != null ? c.arn : aws_imagebuilder_component.this[c.name].arn
  ]
}

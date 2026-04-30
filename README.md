# terraform-aws-image-builder

Terraform module for creating AWS EC2 Image Builder pipelines with automatic recipe versioning, configurable component composition, and AMI lifecycle management.

## Features

- **Automatic recipe versioning** via `time_static` — recipe version bumps only when inputs change
- **Automatic component versioning** — inline component versions bump when YAML content changes
- **Mixed component sources** — pass existing component ARNs or inline YAML to create new ones
- **AMI lifecycle management** — count-based retention policy to clean up old images
- **Cross-account distribution** — configurable launch permissions per region
- **Enable/disable toggle** — deprecate pipelines without destroying resources

## Usage

### Basic pipeline with existing components

```hcl
module "my_pipeline" {
  source = "git::https://git@github.com/ucopacme/terraform-aws-image-builder.git//?ref=v0.0.1"

  name         = "my-app-dev-baseline"
  parent_image = "ami-0123456789abcdef0"

  components = [
    { arn = aws_imagebuilder_component.install_base.arn },
  ]

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.builds.arn

  distribution_regions = [{
    region      = "us-west-2"
    account_ids = ["111111111111", "222222222222"]
  }]

  schedule_expression         = "cron(0 21 3 * ? *)"
  lifecycle_execution_role_arn = aws_iam_role.lifecycle.arn
  tags                        = local.tags
}
```

### Pipeline with inline component and EBS encryption

```hcl
module "my_app" {
  source = "git::https://git@github.com/ucopacme/terraform-aws-image-builder.git//?ref=v0.0.1"

  name         = "my-app-dev-webserver"
  description  = "Application webserver image"
  parent_image = module.baseline.image_arn

  components = [
    { arn = aws_imagebuilder_component.install_deps.arn },
    {
      name = "my-app-dev-install-app"
      data = templatefile("${path.module}/components/install-app.yml", {
        s3_bucket = "my-build-artifacts-bucket"
        app_name  = "my-app"
      })
    },
  ]

  ebs_root_volume = {
    volume_size = 40
    kms_key_id  = aws_kms_key.ami.arn
  }

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.builds.arn

  distribution_regions = [{
    region      = "us-west-2"
    account_ids = ["111111111111", "222222222222"]
  }]

  schedule_expression         = "cron(0 21 ? * fri *)"
  lifecycle_execution_role_arn = aws_iam_role.lifecycle.arn
  tags                        = local.tags
}
```

### Chaining pipelines

Use the `image_arn` output as the `parent_image` for downstream pipelines:

```hcl
module "baseline" {
  source       = "git::https://git@github.com/ucopacme/terraform-aws-image-builder.git//?ref=v0.0.1"
  name         = "my-baseline"
  parent_image = "ami-0123456789abcdef0"
  # ...
}

module "app_image" {
  source       = "git::https://git@github.com/ucopacme/terraform-aws-image-builder.git//?ref=v0.0.1"
  name         = "my-app-image"
  parent_image = module.baseline.image_arn  # uses x.x.x wildcard
  # ...
}
```

## Resources Created

- `aws_imagebuilder_image_pipeline` — the pipeline
- `aws_imagebuilder_image_recipe` — AMI recipe with automatic versioning
- `aws_imagebuilder_distribution_configuration` — distribution settings
- `aws_imagebuilder_lifecycle_policy` — AMI retention (when `ami_retention_count` is set)
- `aws_imagebuilder_component` — only for components with inline `data`
- `time_static` — drives recipe and component version changes

## Resources NOT Created (pass in from deployment repo)

- Infrastructure configuration
- Shared components
- KMS keys
- Security groups
- IAM roles and instance profiles

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_imagebuilder_component.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_component) | resource |
| [aws_imagebuilder_distribution_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_distribution_configuration) | resource |
| [aws_imagebuilder_image_pipeline.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_image_pipeline) | resource |
| [aws_imagebuilder_image_recipe.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_image_recipe) | resource |
| [aws_imagebuilder_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/imagebuilder_lifecycle_policy) | resource |
| [time_static.component_version](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.recipe_version](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_retention_count"></a> [ami\_retention\_count](#input\_ami\_retention\_count) | Number of AMIs to retain. Null to disable lifecycle management. | `number` | `10` | no |
| <a name="input_components"></a> [components](#input\_components) | Ordered list of components. Provide arn for existing, or name+data for module-created. | <pre>list(object({<br>    arn  = optional(string)<br>    name = optional(string)<br>    data = optional(string)<br>  }))</pre> | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description for the pipeline | `string` | `null` | no |
| <a name="input_distribution_regions"></a> [distribution\_regions](#input\_distribution\_regions) | List of distribution region configurations | <pre>list(object({<br>    region      = string<br>    ami_name    = optional(string, "{{imagebuilder:imageName}} {{imagebuilder:buildDate}}")<br>    ami_tags    = optional(map(string), {})<br>    account_ids = optional(list(string), [])<br>    kms_key_id  = optional(string)<br>  }))</pre> | n/a | yes |
| <a name="input_ebs_root_volume"></a> [ebs\_root\_volume](#input\_ebs\_root\_volume) | Root EBS volume configuration. Null to omit block device mapping. | <pre>object({<br>    device_name           = optional(string, "/dev/sda1")<br>    volume_size           = number<br>    volume_type           = optional(string, "gp3")<br>    iops                  = optional(number, 3000)<br>    throughput            = optional(number, 125)<br>    kms_key_id            = optional(string)<br>    encrypted             = optional(bool, true)<br>    delete_on_termination = optional(bool, true)<br>  })</pre> | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the pipeline is enabled. Set false to deprecate without destroying. | `bool` | `true` | no |
| <a name="input_image_scanning_enabled"></a> [image\_scanning\_enabled](#input\_image\_scanning\_enabled) | Whether to enable image scanning | `bool` | `false` | no |
| <a name="input_image_tests_enabled"></a> [image\_tests\_enabled](#input\_image\_tests\_enabled) | Whether image tests are enabled | `bool` | `true` | no |
| <a name="input_image_tests_timeout"></a> [image\_tests\_timeout](#input\_image\_tests\_timeout) | Timeout in minutes for image tests | `number` | `720` | no |
| <a name="input_infrastructure_configuration_arn"></a> [infrastructure\_configuration\_arn](#input\_infrastructure\_configuration\_arn) | ARN of the infrastructure configuration to use for builds | `string` | n/a | yes |
| <a name="input_lifecycle_execution_role_arn"></a> [lifecycle\_execution\_role\_arn](#input\_lifecycle\_execution\_role\_arn) | IAM role ARN for lifecycle policy execution. Required when ami\_retention\_count is set. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the pipeline, recipe, and distribution configuration | `string` | n/a | yes |
| <a name="input_parent_image"></a> [parent\_image](#input\_parent\_image) | AMI ID or Image Builder image ARN (use x.x.x suffix for latest) | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Platform for components and recipe (Linux or Windows) | `string` | `"Linux"` | no |
| <a name="input_schedule_condition"></a> [schedule\_condition](#input\_schedule\_condition) | When to start pipeline execution on schedule | `string` | `"EXPRESSION_MATCH_ONLY"` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Cron expression for pipeline schedule. Null to disable scheduling. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_uninstall_ssm_agent"></a> [uninstall\_ssm\_agent](#input\_uninstall\_ssm\_agent) | Whether to remove the SSM agent after the image has been built | `bool` | `false` | no |
| <a name="input_working_directory"></a> [working\_directory](#input\_working\_directory) | Working directory for build steps | `string` | `"/tmp"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | ARN of the distribution configuration |
| <a name="output_image_arn"></a> [image\_arn](#output\_image\_arn) | Image ARN with x.x.x wildcard for use as parent\_image in downstream pipelines |
| <a name="output_pipeline_arn"></a> [pipeline\_arn](#output\_pipeline\_arn) | ARN of the image pipeline |
| <a name="output_recipe_arn"></a> [recipe\_arn](#output\_recipe\_arn) | ARN of the image recipe (specific version) |
<!-- END_TF_DOCS -->

################################################################################
# Identity
################################################################################

variable "name" {
  description = "Name for the pipeline, recipe, and distribution configuration"
  type        = string
}

variable "description" {
  description = "Description for the pipeline"
  type        = string
  default     = null
}

variable "platform" {
  description = "Platform for components and recipe (Linux or Windows)"
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.platform)
    error_message = "Platform must be Linux or Windows."
  }
}

################################################################################
# Recipe
################################################################################

variable "parent_image" {
  description = "AMI ID or Image Builder image ARN (use x.x.x suffix for latest)"
  type        = string
}

variable "components" {
  description = "Ordered list of components. Provide arn for existing, or name+data for module-created."
  type = list(object({
    arn  = optional(string)
    name = optional(string)
    data = optional(string)
  }))

  validation {
    condition = alltrue([
      for c in var.components : (c.arn != null) != (c.data != null)
    ])
    error_message = "Each component must have either arn or data, not both."
  }

  validation {
    condition = alltrue([
      for c in var.components : c.arn != null || c.name != null
    ])
    error_message = "Components with data must also specify a name."
  }
}

variable "ebs_root_volume" {
  description = "Root EBS volume configuration. Null to omit block device mapping."
  type = object({
    device_name           = optional(string, "/dev/sda1")
    volume_size           = number
    volume_type           = optional(string, "gp3")
    iops                  = optional(number, 3000)
    throughput            = optional(number, 125)
    kms_key_id            = optional(string)
    encrypted             = optional(bool, true)
    delete_on_termination = optional(bool, true)
  })
  default = null
}

variable "working_directory" {
  description = "Working directory for build steps"
  type        = string
  default     = "/tmp"
}

variable "uninstall_ssm_agent" {
  description = "Whether to remove the SSM agent after the image has been built"
  type        = bool
  default     = false
}

################################################################################
# Infrastructure (passed in)
################################################################################

variable "infrastructure_configuration_arn" {
  description = "ARN of the infrastructure configuration to use for builds"
  type        = string
}

################################################################################
# Distribution
################################################################################

variable "distribution_regions" {
  description = "List of distribution region configurations"
  type = list(object({
    region      = string
    ami_name    = optional(string, "{{imagebuilder:imageName}} {{imagebuilder:buildDate}}")
    ami_tags    = optional(map(string), {})
    account_ids = optional(list(string), [])
    kms_key_id  = optional(string)
  }))
}

################################################################################
# Schedule
################################################################################

variable "schedule_expression" {
  description = "Cron expression for pipeline schedule. Null to disable scheduling."
  type        = string
  default     = null
}

variable "schedule_condition" {
  description = "When to start pipeline execution on schedule"
  type        = string
  default     = "EXPRESSION_MATCH_ONLY"

  validation {
    condition     = contains(["EXPRESSION_MATCH_ONLY", "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"], var.schedule_condition)
    error_message = "Must be EXPRESSION_MATCH_ONLY or EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE."
  }
}

################################################################################
# Testing
################################################################################

variable "image_tests_enabled" {
  description = "Whether image tests are enabled"
  type        = bool
  default     = true
}

variable "image_tests_timeout" {
  description = "Timeout in minutes for image tests"
  type        = number
  default     = 720
}

################################################################################
# Lifecycle
################################################################################

variable "enabled" {
  description = "Whether the pipeline is enabled. Set false to deprecate without destroying."
  type        = bool
  default     = true
}

variable "ami_retention_count" {
  description = "Number of AMIs to retain. Null to disable lifecycle management."
  type        = number
  default     = 10
}

variable "lifecycle_execution_role_arn" {
  description = "IAM role ARN for lifecycle policy execution. Required when ami_retention_count is set."
  type        = string
  default     = null
}

################################################################################
# Scanning
################################################################################

variable "image_scanning_enabled" {
  description = "Whether to enable image scanning"
  type        = bool
  default     = false
}

################################################################################
# Meta
################################################################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

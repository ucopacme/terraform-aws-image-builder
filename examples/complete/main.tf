terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "this" {}

locals {
  name        = "example-imagebuilder"
  environment = "dev"

  # Replace with real values
  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
  s3_bucket = "my-build-artifacts-${data.aws_caller_identity.this.account_id}"

  distribution_account_ids = [] # Add target account IDs for cross-account distribution

  tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

################################################################################
# Shared Infrastructure
################################################################################

resource "aws_kms_key" "ami" {
  description             = "Image Builder AMI encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_security_group" "builds" {
  name   = "${local.name}-sg"
  vpc_id = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow egress to anywhere"
  }

  tags = merge(local.tags, { Name = "${local.name}-sg" })
}

resource "aws_iam_role" "build" {
  name = "${local.name}-build"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "imagebuilder" {
  role       = aws_iam_role.build.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "build" {
  name = "${local.name}-build"
  role = aws_iam_role.build.name
  tags = local.tags
}

resource "aws_iam_role" "lifecycle" {
  name = "${local.name}-lifecycle"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "imagebuilder.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lifecycle" {
  role       = aws_iam_role.lifecycle.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/EC2ImageBuilderLifecycleExecutionPolicy"
}

resource "aws_imagebuilder_infrastructure_configuration" "builds" {
  name                          = local.name
  instance_profile_name         = aws_iam_instance_profile.build.name
  instance_types                = ["t3.medium"]
  subnet_id                     = local.subnet_id
  security_group_ids            = [aws_security_group.builds.id]
  terminate_instance_on_failure = true

  instance_metadata_options {
    http_tokens = "required"
  }

  tags = local.tags
}

################################################################################
# Shared Component — created outside the module, passed in by ARN
################################################################################

resource "aws_imagebuilder_component" "install_base" {
  name     = "${local.name}-install-base"
  version  = "1.0.0"
  platform = "Linux"

  data = yamlencode({
    schemaVersion = "1.0"
    phases = [{
      name = "build"
      steps = [{
        name   = "UpdateSystem"
        action = "ExecuteBash"
        inputs = {
          commands = ["set -e", "yum update -q -y || dnf update -q -y"]
        }
      }]
    }]
  })

  skip_destroy = true
  tags         = local.tags
}

################################################################################
# Pipeline — uses the module
################################################################################

module "app_image" {
  source = "../../"

  name         = "${local.name}-app"
  description  = "Application server image"
  parent_image = "ami-0123456789abcdef0" # Replace with a real AMI or Image Builder image ARN

  components = [
    # Shared component — passed by ARN
    { arn = aws_imagebuilder_component.install_base.arn },

    # Inline component — module creates and versions it automatically
    {
      name = "${local.name}-install-app"
      data = templatefile("${path.module}/components/install-app.yml", {
        s3_bucket = local.s3_bucket
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
    account_ids = local.distribution_account_ids
  }]

  schedule_expression          = "cron(0 21 ? * fri *)"
  lifecycle_execution_role_arn = aws_iam_role.lifecycle.arn
  ami_retention_count          = 10
  tags                         = local.tags
}

################################################################################
# Outputs
################################################################################

output "pipeline_arn" {
  value = module.app_image.pipeline_arn
}

output "image_arn" {
  description = "Use as parent_image in downstream pipelines"
  value       = module.app_image.image_arn
}

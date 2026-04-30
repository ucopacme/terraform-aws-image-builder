# Complete Example

This example demonstrates a full Image Builder deployment with:

- Shared infrastructure (KMS, IAM, security group, infrastructure configuration)
- Shared components managed outside the module
- A pipeline that mixes shared component ARNs with an inline component
- EBS encryption with a custom KMS key
- Cross-account AMI distribution
- Weekly scheduled builds with lifecycle retention

## Architecture

```
main.tf              — Shared infra + module call
components/
  install-app.yml    — Inline component: downloads application artifacts from S3
```

The shared resources would typically live in a separate Terraform workspace. They are combined here for simplicity.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

Replace the placeholder VPC, subnet, and S3 bucket values in `main.tf` with real values before applying. This example is intended as a reference, not a standalone deployment.

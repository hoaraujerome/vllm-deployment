# network-vpc

Creates an AWS VPC with optional subnets. DNS support and DNS hostnames are enabled on the VPC.

Subnet map keys are stable logical names. Use those keys to look up subnet IDs from the `subnet_ids` output — not AWS `Name` tags.

Organizational tags (`ManagedBy`, `Project`, `Environment`, `Stack`, etc.) belong in the live root AWS provider `default_tags` block, not in this module.

## Example

```hcl
module "vpc" {
  source = "../../../../../modules/infra/network-vpc"

  vpc_ipv4_cidr_block = "10.50.0.0/16"
  subnets = {
    packer = {
      ipv4_cidr_block         = "10.50.1.0/24"
      map_public_ip_on_launch = true
    }
  }
}

# module.vpc.subnet_ids["packer"]
```

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | ~> 1.15.0 |
| aws | ~> 6.60.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| vpc_ipv4_cidr_block | IPv4 CIDR block for the VPC. | `string` | n/a | yes |
| subnets | Subnets to create in the VPC, keyed by a stable logical name used in module outputs. | `map(object({ ipv4_cidr_block = string, map_public_ip_on_launch = bool }))` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| vpc_id | ID of the VPC. |
| subnet_ids | Map of subnet logical name to subnet ID. |

## Resources

| Name | Type |
| ---- | ---- |
| aws_vpc.this | resource |
| aws_subnet.this | resource |

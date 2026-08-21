# network-securitygroup

Creates one or more VPC security groups keyed by stable logical names.

AWS security group `name` and `Name` tags are prefixed with `tag_prefix`. Output map keys remain the logical names passed in `names` (for example `k8s-node`), not the prefixed AWS names.

## Example

```hcl
module "security_groups" {
  source = "../../../modules/network-securitygroup"

  tag_prefix = local.tag_prefix
  vpc_id     = module.vpc.vpc_id
  names = [
    "ec2-instance-connect-endpoint",
    "k8s-node",
  ]
}

# module.security_groups.security_group_ids["k8s-node"]
```

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | ~> 1.15.0 |
| aws | ~> 6.60.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| vpc_id | ID of the VPC that owns the security groups. | `string` | n/a | yes |
| names | Logical names for security groups to create. | `set(string)` | n/a | yes |
| tag_prefix | Prefix for AWS security group names and Name tags. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| security_group_ids | Map of logical name to security group ID. |

## Resources

| Name | Type |
| ---- | ---- |
| aws_security_group.this | resource |

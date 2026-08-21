# network-internetgateway

Creates an internet gateway attached to a VPC.

Organizational tags belong in the live root AWS provider `default_tags` block, not in this module.

## Example

```hcl
module "internet_gateway" {
  source = "../../../../../modules/infra/network-internetgateway"

  vpc_id = module.vpc.vpc_id
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | ~> 1.15.0 |
| aws | ~> 6.60.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| vpc_id | ID of the VPC to attach the internet gateway to. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the internet gateway. |

## Resources

| Name | Type |
| ---- | ---- |
| aws_internet_gateway.this | resource |

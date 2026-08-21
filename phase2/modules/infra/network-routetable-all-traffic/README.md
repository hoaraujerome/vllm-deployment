# network-routetable-all-traffic

Creates a route table with a default route (`0.0.0.0/0`) to an internet gateway or NAT gateway, and associates it with one subnet.

Use `gateway_type = "igw"` for public subnets and `gateway_type = "nat"` for private subnets that egress via a NAT gateway.

Organizational tags belong in the live root AWS provider `default_tags` block, not in this module.

## Example

```hcl
module "internet_gateway_route_table" {
  source = "../../../../../modules/infra/network-routetable-all-traffic"

  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.subnet_ids["packer"]
  gateway_id   = module.internet_gateway.id
  gateway_type = "igw"
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
| vpc_id | ID of the VPC that owns the route table. | `string` | n/a | yes |
| subnet_id | ID of the subnet to associate with the route table. | `string` | n/a | yes |
| gateway_id | ID of the internet gateway or NAT gateway used for the default route. | `string` | n/a | yes |
| gateway_type | Gateway type for the default route: `igw` or `nat`. | `string` | n/a | yes |

## Outputs

This module does not expose outputs.

## Resources

| Name | Type |
| ---- | ---- |
| aws_route_table.this | resource |
| aws_route_table_association.this | resource |

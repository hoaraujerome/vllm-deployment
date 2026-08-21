# network-natgateway

Creates an Elastic IP and a public NAT gateway in the given subnet.

Organizational tags belong in the live root AWS provider `default_tags` block.

## Example

```hcl
module "nat_gateway" {
  source = "../../modules/infra/network-natgateway"

  subnet_id = module.vpc.subnet_ids["nat-gateway"]
}
```

## Outputs

| Name | Description |
| ---- | ----------- |
| id | NAT gateway ID. |

# network-securitygrouprules

Attaches ingress and egress rules to a single security group using the AWS VPC security group rule resources.

Each rule is keyed by a stable logical name in the `rules` map. Set `direction` to `inbound` or `outbound`. Each rule must specify either `cidr_ipv4` or `referenced_security_group_id`, not both.

## Example

```hcl
module "k8s_node_security_group_rules" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = module.security_groups.security_group_ids["k8s-node"]
  rules = {
    ssh_from_eice_ingress = {
      description                  = "SSH from EC2 Instance Connect Endpoint"
      direction                    = "inbound"
      from_port                    = 22
      to_port                      = 22
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.security_groups.security_group_ids["ec2-instance-connect-endpoint"]
    }
  }
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
| security_group_id | ID of the security group to attach rules to. | `string` | n/a | yes |
| rules | Security group rules keyed by a stable logical name. | `map(object({ description = optional(string), direction = string, from_port = number, to_port = number, ip_protocol = string, cidr_ipv4 = optional(string), referenced_security_group_id = optional(string) }))` | n/a | yes |
| tag_prefix | Prefix for security group rule Name tags. | `string` | n/a | yes |

## Outputs

No outputs.

## Resources

| Name | Type |
| ---- | ---- |
| aws_vpc_security_group_ingress_rule.this | resource |
| aws_vpc_security_group_egress_rule.this | resource |

# Elastic IP Module

Allocates an AWS Elastic IP and optionally associates it with an EC2 instance.

The EIP `Name` tag is prefixed with `tag_prefix`.

## Usage

```hcl
module "wireguard_eip" {
  source = "../../../../../modules/infra/network-eip"

  tag_prefix  = local.tag_prefix
  instance_id = module.wireguard.instance_id
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tag_prefix | Prefix for the EIP Name tag. | `string` | n/a | yes |
| instance_id | EC2 instance ID to associate with the EIP. If null, EIP is allocated but not associated. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | EIP allocation ID |
| public_ip | The Elastic IP address |
| association_id | EIP association ID (if associated) |

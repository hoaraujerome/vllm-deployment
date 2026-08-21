# network-ec2-instance-connect-endpoint

Creates an EC2 Instance Connect Endpoint in a private subnet for SSH access to cluster nodes without a bastion.

Attach a dedicated security group that allows outbound SSH to the node security group. The endpoint `Name` tag is prefixed with `tag_prefix`.

## Example

```hcl
module "ec2_instance_connect_endpoint" {
  source = "../../../modules/network-ec2-instance-connect-endpoint"

  tag_prefix = local.tag_prefix
  subnet_id  = module.vpc.subnet_ids["k8s-cluster"]
  security_group_ids = [
    module.security_groups.security_group_ids["ec2-instance-connect-endpoint"],
  ]
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
| subnet_id | ID of the subnet for the EC2 Instance Connect Endpoint. | `string` | n/a | yes |
| security_group_ids | Security group IDs attached to the endpoint. | `set(string)` | n/a | yes |
| tag_prefix | Prefix for the endpoint Name tag. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the EC2 Instance Connect Endpoint. |

## Resources

| Name | Type |
| ---- | ---- |
| aws_ec2_instance_connect_endpoint.this | resource |

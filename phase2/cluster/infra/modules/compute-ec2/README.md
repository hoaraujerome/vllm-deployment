# compute-ec2

Creates a private EC2 instance for the Phase 2 kubeadm node. Resolves the latest available custom AMI built by `phase2/images` Packer (arm64, EBS, self-owned).

Organizational tags belong in the live root AWS provider `default_tags` block. Set instance `Name` and `Role` via the `tags` input.

## Example

```hcl
module "k8s_node" {
  source = "../../../modules/compute-ec2"

  ami_name_prefix    = "vllm-phase2-kubeadm"
  subnet_id          = module.vpc.subnet_ids["k8s-cluster"]
  security_group_ids = [module.security_groups.security_group_ids["k8s-node"]]
  key_pair_name      = module.ssh_public_key.key_pair_name
  tags = {
    Name = "${local.tag_prefix}k8s-node"
    Role = "k8s-node"
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
| ami_name_prefix | Name prefix for the custom kubeadm AMI built by phase2/images Packer. | `string` | n/a | yes |
| subnet_id | ID of the subnet for the EC2 instance. | `string` | n/a | yes |
| security_group_ids | Security group IDs attached to the instance. | `set(string)` | n/a | yes |
| key_pair_name | Name of the EC2 key pair. | `string` | n/a | yes |
| instance_type | EC2 instance type. | `string` | `"t4g.small"` | no |
| tags | Tags applied to the EC2 instance (Name should be set by the caller). | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| instance_id | ID of the EC2 instance. |

## Resources

| Name | Type |
| ---- | ---- |
| data.aws_ami.k8s | data source |
| aws_instance.this | resource |

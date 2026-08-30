# compute-sshpublickey

Registers an SSH public key as an AWS EC2 key pair for cluster node access via EC2 Instance Connect.

The key pair name is prefixed with `tag_prefix` to avoid collisions with other stacks in the same account and region (for example `vllm-phase2-ssh-key-pair`).

## Example

```hcl
module "ssh_public_key" {
  source = "../../../modules/compute-sshpublickey"

  tag_prefix      = local.tag_prefix
  public_key_path = var.ssh_public_key_path
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
| public_key_path | Path to the SSH public key file. | `string` | n/a | yes |
| tag_prefix | Prefix for the EC2 key pair name (unique per account/region). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| key_pair_name | Name of the created EC2 key pair. |

## Resources

| Name | Type |
| ---- | ---- |
| aws_key_pair.this | resource |

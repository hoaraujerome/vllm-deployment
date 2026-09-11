# Ubuntu 26.04 EC2 Module

Creates an EC2 instance with Ubuntu 26.04 LTS ARM64, encrypted root volume, and IMDSv2 required.

AMI lookup is encapsulated within the module (most recent Ubuntu 26.04 ARM64 from Canonical).

When public access uses a separate `aws_eip_association`, keep `associate_public_ip_address = false` and rely on the module's `lifecycle.ignore_changes` for that attribute — the AWS provider otherwise reports perpetual ForceNew drift after EIP attach ([provider-aws#47100](https://github.com/hashicorp/terraform-provider-aws/issues/47100)).

## Usage

```hcl
module "wireguard" {
  source = "../../../modules/compute-ec2-ubuntu2604"

  instance_type               = "t4g.nano"
  subnet_id                   = data.aws_subnet.nat_gateway.id
  associate_public_ip_address = false
  security_group_ids          = [module.wireguard_sg.security_group_ids["wireguard"]]
  key_pair_name               = module.ssh_key.key_pair_name
  user_data                   = file("${path.module}/user_data.sh")
  tags = {
    Name = "vllm-phase3-vpn-wireguard"
    Role = "wireguard"
  }
}
```



## Inputs


| Name                        | Description                                                | Type           | Default | Required |
| --------------------------- | ---------------------------------------------------------- | -------------- | ------- | -------- |
| instance_type               | EC2 instance type                                          | `string`       | n/a     | yes      |
| subnet_id                   | Subnet ID where the instance will be launched              | `string`       | n/a     | yes      |
| associate_public_ip_address | Whether to associate a public IP address with the instance | `bool`         | `false` | no       |
| security_group_ids          | List of security group IDs to attach to the instance       | `list(string)` | n/a     | yes      |
| key_pair_name               | SSH key pair name for instance access                      | `string`       | n/a     | yes      |
| user_data                   | User data script to run on instance launch                 | `string`       | `null`  | no       |
| tags                        | Tags to apply to the instance                              | `map(string)`  | `{}`    | no       |



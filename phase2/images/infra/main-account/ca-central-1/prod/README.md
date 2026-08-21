# AMI builder live root (Packer network)

Ephemeral AWS network for Packer AMI builds: VPC, public subnet, internet gateway, and default route. Outputs `packer_vpc_id` and `packer_subnet_id` for `images/config/packer/`.

Orchestrated by [`images/setup-images.sh`](../../../../setup-images.sh) (`plan` | `deploy` | `build` | `destroy`).

## Tagging

Common tags are set once on the AWS provider via `default_tags` in `provider.tf` (`ManagedBy`, `Project`, `Environment`, `Stack`). Child modules set only resource-specific `Name` tags (for example `vpc`, `packer`, `internet-gateway`).

## State: local backend (intentional)

This live root does **not** configure a remote backend. Terraform stores state in **`terraform.tfstate`** in this directory (local backend default).

That is acceptable here because builder infra is **short-lived**: apply → Packer build → destroy. See [Phase 2 README](../../../../../README.md) for the full layout.

### Tradeoffs

| Local state | Implication |
| ----------- | ----------- |
| Machine-local | State lives on the machine that ran `terraform apply`. Another laptop or CI runner does not see it unless you copy the file. |
| Same workspace for destroy | Run `./images/setup-images.sh destroy` from the **same directory and state file** that performed the apply. Otherwise Terraform may plan to recreate resources or miss ones still running in AWS. |
| No team locking | Without S3 + DynamoDB (or similar), two people cannot safely share applies on the same live root. |
| Not in git | `*.tfstate*` and `.terraform/` are gitignored at the repo root. Do not commit state. |

### When to add a remote backend

Consider S3 (+ DynamoDB lock table) if you need shared applies, CI-driven deploy/destroy, or state that survives disk loss. The cluster live root (`provisioning/envs/dev/`) will likely need remote state sooner because it is long-lived.

## Related paths

| Path | Role |
| ---- | ---- |
| `phase2/modules/infra/` | Shared child modules (no state) |
| `phase2/images/config/packer/` | Packer build config |
| `phase2/provisioning/envs/dev/` | Cluster live root (separate state) |

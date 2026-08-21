# Cluster live root (prod)

Long-lived kubeadm cluster on AWS: VPC, NAT, EC2 Instance Connect Endpoint, single `t4g.small` node (control plane + worker).

Gruntwork-style path aligned with the AMI builder live root: `main-account/<region>/<environment>/`.

## Prerequisites

- Custom AMI from `make images-config-build` (`vllm-phase2-kubeadm*` in `ca-central-1`)
- SSH public key path (see `terraform.tfvars.example`)

## Commands

Use the [Makefile](../../../../Makefile) (primary entrypoint):

```bash
make cluster-infra-plan      # fmt, validate, trivy, plan
make cluster-infra-validate  # fmt, validate, trivy (no plan)
make cluster-infra-deploy    # plan + apply
make cluster-infra-destroy   # destroy
```

Makefile recipes invoke [`cluster/setup-cluster.sh`](../../../../setup-cluster.sh).

## Tagging

Organizational tags are set on the AWS provider via `default_tags` in `provider.tf`. Child modules set resource `Name` tags only.

## State

Local backend by default (`terraform.tfstate` in this directory).

## Related

| Path | Role |
| ---- | ---- |
| `phase2/Makefile` | Primary entrypoint |
| `phase2/modules/infra/` | Shared network modules |
| `phase2/cluster/infra/modules/` | Cluster-specific modules (EC2, EICE, SG) |
| `phase2/images/setup-images.sh` | AMI factory (invoked by Makefile) |
| `phase2/cluster/setup-cluster.sh` | Cluster TF (invoked by Makefile) |

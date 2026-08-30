# VPN live root (prod)

WireGuard VPN server in the Phase 2 VPC (Option A: nat-gateway subnet).

Gruntwork/Terragrunt-style path aligned with Phase 2 cluster live root: `main-account/<region>/<environment>/`.

## Prerequisites

- **Phase 2 cluster running** — `cd ~/DEV/vllm-deployment/phase2 && devbox shell` then `make check-cluster` must exit 0
- **Phase 2 resources tagged** — VPC, subnets, SGs, K8s node must have expected tags (created via Phase 2 Terraform)

## Data sources

Phase 3 uses **direct AWS data sources** (not `terraform_remote_state`) to discover Phase 2 resources:

| Data source | Discovers |
|-------------|-----------|
| `data.aws_vpc.phase2` | VPC by tag `vllm-phase2-cluster-vpc` |
| `data.aws_subnet.nat_gateway` | nat-gateway subnet by tag |
| `data.aws_security_group.k8s_node` | K8s node SG by tag |
| `data.aws_instance.k8s_node` | K8s node instance by tag + running state |
| `data.http.current_ip` | Your current public IP (dynamic, fetched on every plan/apply) |

## Resources

| Resource | Purpose |
|----------|---------|
| `aws_instance.wireguard` | t4g.nano in nat-gateway subnet (cloud-init placeholder) |
| `aws_eip.wireguard` | Elastic IP for WireGuard endpoint |
| `aws_security_group.wireguard` | UDP 51820 from home IP, SSH break-glass |
| `aws_vpc_security_group_ingress_rule.k8s_api_from_wireguard` | TCP 6443 on K8s node from WireGuard SG |
| `aws_key_pair.wireguard` | SSH key for WireGuard EC2 |

## Commands

Use the [phase3 Makefile](../../../../../Makefile) (primary entrypoint):

```bash
make check-provisioning                            # gate 2 plan
make check-provisioning RUN_PROVISIONING_APPLY=1   # gate 2 + 3 apply
```

## Module architecture

The live root orchestrates infrastructure through module calls (Gruntwork/Terragrunt pattern):

| File | Responsibility |
|------|----------------|
| `main.network.tf` | Phase 2 resource discovery (data sources) |
| `main.wireguard.tf` | WireGuard VPN server + security (module calls) |
| `locals.tf` | Tag prefix and ports/protocols |
| `variables.tf` | Live root inputs |
| `outputs.tf` | Exposed values |

## Shared modules

Phase 3 reuses infrastructure modules from `phase2/modules/infra/`:

| Module | Purpose |
|--------|---------|
| `compute-sshpublickey` | SSH key pair |
| `network-securitygroup` | Security group shell |
| `network-securitygrouprules` | SG ingress/egress rules |
| `compute-ec2-simple` | EC2 instance (simplified vs cluster-specific module) |
| `network-eip` | Elastic IP + association |

## Phase 3 modules

VPN modules live under `../../../modules/` (local to Phase 3):

| Module | Purpose |
|--------|---------|
| `compute-sshpublickey` | SSH key pair |
| `network-securitygroup` | Security group shell |
| `network-securitygrouprules` | SG ingress/egress rules |
| `compute-ec2-ubuntu2604` | EC2 with Ubuntu 26.04 ARM64 (AMI lookup encapsulated) |
| `network-eip` | Elastic IP + association |

These modules remain local until a third use case emerges (rule of three), at which point they can be extracted to `phase2/modules/infra/`.

## Usage

1. **Copy `terraform.tfvars.example` to `terraform.tfvars`:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` if needed:**

   - `ssh_public_key_path` defaults to `~/.ssh/id_rsa_k8s_homelab.pub`
   - **Home IP is fetched dynamically** — no manual configuration needed

## Outputs

| Output | Use |
|--------|-----|
| `wireguard_public_ip` | WireGuard client `Endpoint` |
| `wireguard_private_ip` | VPC internal IP |
| `k8s_node_private_ip` | Kubeconfig `server` URL |
| `current_home_ip` | Your current IP (dynamic, updates on every run) |

## State

Local backend by default (`terraform.tfstate` in this directory).

## Cloud-init

User data is a **placeholder** — WireGuard installation and configuration deferred to next step (work order step 4).

## Security

- **Home IP:** Dynamically fetched via `data.http` from `https://ifconfig.me/ip` on every plan/apply
- **Egress:** Restricted to VPC CIDR + HTTP/HTTPS (not all traffic) — allows VPN routing + package updates
- **OS:** Ubuntu 26.04 LTS ARM64 (matches Phase 2 K8s node)

## Related

| Path | Role |
| ---- | ---- |
| `phase3/Makefile` | Primary entrypoint (`check-provisioning`) |
| `phase2/cluster/infra/main-account/ca-central-1/prod/` | Phase 2 cluster live root (VPC, K8s node) |
| `phase3/configuration/` | WireGuard server bootstrap (cloud-init, client config) |

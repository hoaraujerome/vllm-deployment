# Phase 2 — Kubernetes cluster (AWS)

Bootstrap a **functional Kubernetes cluster** on AWS from greenfield code in this repo. Proves the **cluster contract**: Terraform provisions infrastructure, kubeadm bootstraps the cluster, nodes are Ready, smoke workload runs.

**Status:** not started

**Prerequisite:** [Phase 1](../phase1/README.md) complete (optional — no hard dependency)

**Reference architecture (inspirational, not a fork):** `~/DEV/k8s-homelab`

## Developer setup (devbox)

Phase 2 tooling matches the homelab stack: **Terraform**, **Packer**, **Ansible**, **AWS CLI** — pinned via [devbox](https://www.jetify.com/devbox) under `phase2/` (Phase 1 local vLLM does not use devbox).

### Requirements

- AWS account + AWS CLI credentials configured
- [devbox](https://www.jetify.com/devbox)

### Steps

```bash
cd phase2
devbox shell          # installs pinned tools on first run
./scripts/phase2-check.sh
```

Optional — pre-commit (also in devbox):

```bash
devbox shell
pre-commit install
pre-commit run --all-files
```

### Pinned packages (same set as k8s-homelab)

| Tool | Role |
| ---- | ---- |
| terraform | `provisioning/` — VPC, EC2, EICE |
| packer | `images/` — node AMI build |
| ansible | `images/config/` — kubeadm + cilium-cli bake |
| awscli2 | EICE SSH, SSM, AWS API |
| jq | script / CI parsing |
| git | repo ops |
| pre-commit | fmt/lint hooks |
| trivy | AMI / IaC scan (when wired) |

Run **all** Phase 2 commands (`terraform`, `packer`, `ansible-playbook`, `cluster.sh`, checks) from `devbox shell` so versions match homelab and CI.

## Done when

`./scripts/phase2-check.sh` exits 0:

| Gate | Check | Proves |
| ---- | ----- | ------ |
| TF static | `terraform fmt -check`, `validate` | HCL is sane |
| TF plan | `terraform plan` exits 0 | AWS shape is coherent |
| AMI | Packer build or AMI exists | node image ready |
| Provision | `terraform apply` | EC2 / EICE / network exist |
| Bootstrap | kubeadm init + Cilium | cluster up |
| Cluster | `kubectl get nodes` → Ready | schedulable cluster |
| Smoke | test pod (e.g. nginx) Ready | workload path works |

## Layout

```text
phase2/
├── README.md
├── devbox.json             # pinned TF / Packer / Ansible / awscli (homelab pattern)
├── provisioning/           # Terraform — AWS infra
│   ├── modules/
│   └── envs/dev/
├── images/                 # AMI factory (homelab split)
│   ├── infra/              # ephemeral TF — VPC/subnet for Packer builder
│   └── config/             # Packer + Ansible — bake kubeadm base AMI
├── configuration/          # optional runtime config
└── scripts/
    ├── phase2-check.sh
    └── cluster.sh
```

## Starting spec (Loop 2)

```text
Cloud:    AWS (sandbox account)
Region:   ca-central-1 (Canada Central)
SKU:      t4g.small (ARM64) — upsize in Phase 4 for vLLM
AMI:      Ubuntu 24.04 arm64 — Packer + Ansible (homelab pattern)
Nodes:    1 private node (CP + worker) — homelab uses 1 CP + 1 worker
Access:   EC2 Instance Connect Endpoint → private node (not bastion)
PKI:      kubeadm built-in
CNI:      Cilium 1.20.0 + cilium-cli v0.19.7
K8s:      1.36.3
Scope:    no vLLM, no GPU, no ingress
```

Single-node kubeadm: init on private node, install Cilium, remove control-plane taint so pods can schedule (required for Phase 4 vLLM).

## AMI build (homelab — ephemeral infra, destroy on)

Separate from cluster `provisioning/`. Packer needs a VPC + subnet to launch a throwaway builder EC2; that network is **not** the cluster VPC.

```text
terraform apply   # images/infra — ephemeral VPC + subnet for Packer
packer build      # images/config — Ansible bake on builder EC2 → AMI
terraform destroy # tear down build infra; only the AMI remains
```

Wire this into `cluster.sh configure` (homelab `images-config-build` pattern). Unlike homelab today, **do not** leave `destroy` commented out — always deprovision builder infra after a successful build.

## Ansible — upgrade-ready (design constraint, not Phase 2 gate)

Phase 2 bootstraps a **single node**. By first real upgrade, expect **multiple nodes** (CP + workers).

- Pin **`kubernetes_version: "1.36.3"`**, **`cilium_version: "1.20.0"`**, **`ciliumcli_version: "v0.19.7"`** in one place; template kubeadm config from K8s var
- Idempotent roles
- **Upgrade path (multi-node):** rebuild Packer AMI at new version → rolling replace nodes (workers first, CP last) — not in-place kubeadm upgrade
- **Phase 2 done-when:** cluster at 1.36.3 works — **not** that an upgrade was executed

## Access pattern (EC2 Instance Connect — homelab)

```text
laptop → aws ec2-instance-connect open-tunnel → private k8s node (t4g.small)
```

Homelab README example:

```bash
ssh -i ~/.ssh/id_rsa_… ubuntu@<instance-id> \
  -o ProxyCommand='aws ec2-instance-connect open-tunnel --instance-id <instance-id>'
```

**Not** the KTHW bastion pattern. KTHW is manual kubeadm + custom OpenSSL PKI — different project entirely.

## Mindset — loop engineering

Design `phase2-check.sh` **before** the Terraform modules sprawl. Grow modules and roles only when a gate fails.

Prompt shape for Cursor:

```text
Goal: functional single-node kubeadm cluster on AWS (ca-central-1).
Constraints: 1 private node, t4g.small, EICE access, kubeadm + Cilium, devbox shell, greenfield — inspired by ~/DEV/k8s-homelab, no copy.
Validation: ./phase2/scripts/phase2-check.sh must exit 0.
Current failure: <paste stderr>
Fix only what the checks require.
```

## Orchestrator (stub)

From `devbox shell`:

```bash
./scripts/cluster.sh provision   # terraform apply
./scripts/cluster.sh configure   # packer / kubeadm bootstrap
./scripts/cluster.sh check       # phase2-check.sh
./scripts/cluster.sh destroy     # tear down (TBD)
```

Or: `devbox run check`

## Loop 2 decisions

- **Dev environment:** [devbox](https://www.jetify.com/devbox) in `phase2/` — same package set as k8s-homelab (`terraform`, `packer`, `ansible`, `awscli2`, …)
- **Region:** ca-central-1 (Canada Central)
- **Instance type:** `t4g.small` (ARM64, Ubuntu 24.04)
- **Topology:** 1 private node (CP + worker)
- **Access:** EC2 Instance Connect Endpoint (k8s-homelab pattern)
- **PKI:** kubeadm built-in
- **CNI:** Cilium **1.20.0** + cilium-cli **v0.19.7** ([stable K8s requirements](https://docs.cilium.io/en/stable/network/kubernetes/requirements/) — 1.36 listed)
- **Kubernetes:** 1.36.3
- **SSM bootstrap coordination:** skip for now (single-node; revisit if multi-node)
- **kubectl:** **on the node only** via EICE — laptop kubeconfig in Phase 3 (WireGuard)
- **K8s upgrade path:** rebuild AMI at new version → rolling replace nodes (workers first, CP last). Phase 2 = 1 node; multi-node expected by first upgrade.
- **Packer build infra:** ephemeral (homelab) — `images/infra` Terraform up → `packer build` → **`terraform destroy`**; only the AMI persists

## Next

→ [Phase 3](../phase3/README.md) — WireGuard (replace EICE for laptop kubectl)

# Phase 2 — Kubernetes cluster


**Status:** in progress

**Prerequisite:** [Phase 1](../phase1/README.md) (optional — no hard dependency)

**Repo:** `~/DEV/vllm-deployment/phase2` — Terraform, Ansible/Packer, devbox, **`Makefile`**, validation ladder

**Reference architecture (inspirational, not a fork):** `~/DEV/k8s-homelab` — TF + Packer/Ansible AMI + kubeadm + Cilium on AWS.

---

## Done when

`make check` exits 0 — a functional Kubernetes cluster on AWS with all nodes Ready and a smoke pod running.

---

## Mindset — loop engineering

[Loop engineering](https://www.deeplearning.ai/the-batch/issue-359) — the agent does not decide when Phase 2 is done. **Objective checks do.** Design the validation ladder **before** Terraform modules sprawl.

Phase 2 proves the **cluster contract** — infrastructure, kubeadm bootstrap, schedulable nodes. vLLM is [Phase 4](../phase4/README.md).

### Three loops (what each one is for)


| Loop                        | Cadence           | Who drives it           | Phase 2 role                                                |
| --------------------------- | ----------------- | ----------------------- | ----------------------------------------------------------- |
| **1 — Agentic coding**      | seconds → minutes | Cursor + terminal       | Edit TF/Ansible → run checks → feed failures back → repeat  |
| **2 — Engineer feedback**   | hours             | You (platform engineer) | Reject bad architecture; update constraints; restart Loop 1 |
| **3 — Production feedback** | days              | Metrics + users         | Mostly [Phase 6](../phase6/README.md)                     |


---



## Goal (start here — refine in Loop 2)

Bootstrap a minimal **kubeadm cluster on AWS** from greenfield code: Terraform provisions, custom AMI (Packer + Ansible) or node config, validation ladder proves it works.

Example starting spec:

```text
Goal:     functional K8s cluster on AWS
Cloud:    AWS sandbox account
Region:   ca-central-1 (Canada Central)
Nodes:    1 private node (CP + worker, single-node cluster)
SKU:      t4g.small (ARM64 Graviton) — same as k8s-homelab; upsize in Phase 4 for vLLM RAM
AMI:      Ubuntu Server 26.04 LTS arm64 — custom Packer + Ansible bake
Access:   EC2 Instance Connect Endpoint → private node (no bastion)
Tools:    Terraform (provision), Packer + Ansible (AMI), kubeadm (bootstrap)
K8s:      1.36.3 (bootstrap target — pin in Ansible group_vars)
CNI:      Cilium 1.20.0 + cilium-cli v0.19.7 (stable line; K8s 1.36 in requirements)
PKI:      kubeadm built-in (not custom OpenSSL)
Scope:    no vLLM, no GPU, no ingress
```

**Simplification vs k8s-homelab:** homelab uses **1 CP + 1 worker** (2 nodes); this project uses **1 combined node** for Phase 2 MVP.

---



## Constraints (Loop 2 — update as you learn)

- **Greenfield:** new code under `phase2/` — `k8s-homelab` is inspirational, not a fork
- **Dev environment:** **devbox** in `phase2/` — run all Phase 2 commands from `devbox shell`; pinned toolchain:

| Tool | Version |
| ---- | ------- |
| terraform | 1.15.3 |
| packer | 1.15.3 |
| ansible | 2.21.1 |
| ansible-lint | 25.8.2 |
| awscli2 | 2.34.24 |
| jq | 1.8.2 |
| trivy | 0.72.0 |
| pre-commit | 4.5.1 |
| git | 2.54.0 |

- **Region:** **ca-central-1** (Canada Central)
- **Instance type:** `t4g.small` (2 vCPU, 2 GiB RAM, ARM64) — same as homelab; **revise in [Phase 4](../phase4/README.md)** before vLLM
- **OS:** **Ubuntu Server 26.04 LTS (arm64)** — Packer base AMI; homelab uses 24.04 — do not copy that pin
- **AMI:** custom **Packer + Ansible** image on Ubuntu 26.04 LTS arm64 — containerd, kubeadm, Cilium CLI, and **first-boot bootstrap wiring** (homelab pattern — see below)
- **Topology:** **1 private node** (control plane + worker); remove CP taint so workloads schedule
- **Access:** **EC2 Instance Connect Endpoint (EICE)** — SSH to private nodes (homelab pattern); **not** a bastion
- **PKI:** **kubeadm built-in** — certs under `/etc/kubernetes/pki`; no custom OpenSSL prereq (unlike KTHW)
- **CNI:** **Cilium 1.20.0** + **cilium-cli v0.19.7** — [stable requirements](https://docs.cilium.io/en/stable/network/kubernetes/requirements/) list K8s 1.36; homelab uses 1.17.4 on K8s 1.32 — do not copy that pin
- **Kubernetes version:** **1.36.3** — pin in one variable (`group_vars` / `kubeadm-config`); validate with `kubectl version` in ladder
- **Terraform — shared modules:** `modules/infra/` — reusable child modules (VPC, subnets, etc.); **no backend/state**; consumed by both live roots below; **each child module has `versions.tf`** with the same provider pins as live roots
- **Terraform — variables:** **`nullable = false`** on every `variable` (live roots + `modules/infra/*/` + `cluster/infra/modules/*/`); variables with `default` still set `nullable = false`
- **Terraform — AWS provider:** **`hashicorp/aws` `~> 6.60.0`** on every live root and every `modules/infra/*/` child module (homelab uses `~> 5.86.0` — do not copy); keep pins identical so `make images-infra-plan` module validation does not pull a different provider
- **Terraform — cluster live:** `cluster/infra/main-account/ca-central-1/prod/` — root module for VPC, private subnet, NAT, EICE, EC2, SGs (separate state from AMI build)
- **Terraform — AMI live:** `images/infra/main-account/ca-central-1/prod/` — ephemeral VPC/subnet for Packer builder ([Gruntwork infrastructure-live](https://docs.gruntwork.io/2.0/docs/overview/concepts/infrastructure-live/) pattern, homelab-aligned); **destroy after** `packer build`
- **Packer + Ansible (AMI bake):** `images/config/` — `packer/` + `ansible/ami.yaml` + roles; packages **and** bootstrap machinery (not runtime playbooks from your laptop)
- **Bootstrap (Loop 2):** **homelab first-boot** — baked into the AMI, not Ansible under `configuration/` after Terraform
- **Orchestration (Loop 2):** **`phase2/Makefile`** is the **only** human and automation entrypoint for infra (`make help`). Layering:
  - **`make check`** → `scripts/phase2-check.sh` (validation ladder)
  - **`phase2-check.sh`** → **`make` targets only** — never call `images/setup-images.sh` or `cluster/setup-cluster.sh` directly
  - **Makefile recipes** → `setup-images.sh` / `setup-cluster.sh` (implementation detail)
  - **Flags** (`SKIP_*`, `RUN_*`) are set on the **`make`** command line; Makefile `export`s them to check script and setup scripts (`make check SKIP_TF_APPLY=1`)
- **No vLLM / no GPU** in Phase 2 — cluster factory only



### Ansible — upgrade-ready design (constraint, not a Phase 2 gate)

Write playbooks so a future **version bump** is tractable. **Phase 2 done-when does not require running an upgrade** — only bootstrap at 1.36.3 on a **single node**. By the time a real upgrade happens, expect **multiple nodes** (CP + workers); the path below applies then, not in Phase 2.


| Do from day one                                                                                                                  | Defer to later                      |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| Single `kubernetes_version`, `cilium_version`, `ciliumcli_version`, `containerd_sandbox_image` in `group_vars`                   | Proving an upgrade in Phase 2       |
| **containerd:** `containerd config default` + `/etc/containerd/conf.d/k8s.toml` overrides only (no vendored full `config.toml`) |                                     |
| Template `kubeadm-config.yaml` from that var                                                                                     |                                     |
| Idempotent roles (safe to re-run)                                                                                                |                                     |
| **Upgrade path (multi-node):** rebuild Packer AMI at new version → **rolling replace** nodes (workers first, control plane last) | In-place `kubeadm upgrade` playbook |


Homelab bakes kubelet/kubeadm into the **Packer AMI** at a fixed version. **Loop 2 decision:** version bumps = new AMI + rolling node replace — not runtime `kubeadm upgrade` playbooks. SSM / join coordination (homelab multi-node pattern) is **deferred** until topology grows beyond one node.

### Bootstrap — homelab first-boot (Loop 2)

Same model as `~/DEV/k8s-homelab`: bootstrap is **not** a separate playbook you run from the laptop after `terraform apply`. It is **wired into the AMI** and runs on **first EC2 boot**.

```text
Packer bake (ami.yaml)                Terraform deploy              First boot (automatic)
──────────────────────                ────────────────              ──────────────────────
packages: containerd, kubeadm,        EC2 from custom AMI           cloud-init (99_k8s.cfg)
  cilium-cli, kubeadm-config            private subnet + EICE           → enable/start
templates: kubeadm-init.sh,                                          kubeadm-init.service
  kubeadm-init.service,                                                → kubeadm init
  cloud-init 99_k8s.cfg                                               → cilium install
                                                                      → remove CP taint (single node)
                                                                      → systemctl enable kubelet
```

**Kubelet on reboot:** the AMI bake **disables** kubelet so it cannot start before `kubeadm init`. After init (and on every later boot via the script’s early-exit path), **`kubeadm-init.sh` enables kubelet** so the node rejoins the cluster after reboot. Gate 6 asserts `systemctl is-enabled kubelet`.

**Existing nodes** baked before this fix: one-time repair over EICE — `sudo systemctl enable --now kubelet`, or `sudo systemctl start kubeadm-init.service` after deploying an AMI that includes the updated script.

| Piece | Baked where (Ansible `kubernetes` role) | Runs when |
| ----- | ---------------------------------------- | --------- |
| `/root/kubeadm-config.yaml` | AMI bake | `kubeadm init --config` on first boot |
| `/usr/local/bin/kubeadm-init.sh` | AMI bake | `kubeadm-init.service` |
| `kubeadm-init.service` | AMI bake | enabled by cloud-init |
| `/etc/cloud/cloud.cfg.d/99_k8s.cfg` | AMI bake | first boot → start service |

**Single-node simplification vs homelab:** homelab's script branches on EC2 `Role` tag and uses **SSM** to pass CP IP + worker join command between two nodes. Phase 2 uses **one** combined CP+worker node — script runs `kubeadm init` + `cilium install` only; **no SSM**, no worker join path. Revisit SSM if you split CP and workers later.

**`configuration/`** is not the bootstrap path for Phase 2. Validation gate **Bootstrap** means the first-boot service succeeded and the cluster is up (checked via EICE/`kubectl` on the node), not "ansible-playbook under `configuration/`".

Reject and restart Loop 1 when the agent proposes shortcuts that violate these (e.g. K8s version hardcoded in five files, copy k8s-homelab wholesale, homelab Ubuntu 24.04 base AMI, homelab AWS provider 5.86 pin, child module without `versions.tf`, mismatched provider pins across modules/live, **Terraform `variable` without `nullable = false`**, KTHW-style manual PKI, bastion when homelab uses EICE, public K8s node, **kubelet left disabled after bootstrap**, bundle vLLM into AMI playbooks, merge `images/infra` state with `cluster/infra`, flat `images/infra/envs/dev/` instead of `main-account/ca-central-1/prod/`, duplicate network modules under `cluster/infra/modules/` instead of shared `modules/infra/`, **runtime Ansible bootstrap under `configuration/` instead of AMI first-boot**, **`phase2-check.sh` calling `setup-images.sh` or `setup-cluster.sh` directly instead of `make` targets**, bypassing the Makefile for infra gates).

### Terraform layout (Loop 2)

Gruntwork-style **modules vs live**, simplified for one sandbox account. Inspired by k8s-homelab — greenfield paths, not a fork. **One shared module library**; two live roots with separate state.

| Purpose | Path | State |
| ------- | ---- | ----- |
| Shared infra modules (blueprints) | `modules/infra/` | none |
| Cluster live | `cluster/infra/main-account/ca-central-1/prod/` | persistent while cluster exists |
| Packer builder live | `images/infra/main-account/ca-central-1/prod/` | **ephemeral** — apply → build → destroy |
| AMI bake | `images/config/packer/` + `images/config/ansible/` | n/a |

Both live roots call child modules from `modules/infra/` (relative `source` paths).

**Provider pins (Loop 2)** — copy this block to each live root `versions.tf` and each `modules/infra/*/versions.tf`:

```hcl
terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60.0"
    }
  }
}
```

Commit `.terraform.lock.hcl` per live root after `terraform init` (Loop 1); modules use the same constraint but do not commit lock files.

**Child module files (Loop 2)** — under `modules/infra/*/` and `cluster/infra/modules/*/`:

| File | Purpose |
| ---- | ------- |
| `main.tf` | Resources, module calls, locals, data sources |
| `variables.tf` | Input variables |
| `outputs.tf` | Outputs |
| `versions.tf` | `required_version` and `required_providers` |
| `README.md` | Module description (Requirements, Inputs, Outputs, Resources) |

Live roots use `main.*.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `versions.tf`, `locals.tf` — not a single catch-all `main.tf` for everything.

#### Variables

Every `variable` in live roots and child modules:

- Set **`nullable = false`** on all variables, including those with a **`default`** (defaults express optional *values*, not nullability).
- Attribute order: `description`, `type`, `default` (if any), `nullable`, `validation` (if any).
- Do not use `nullable = true` or optional blocks whose presence means “feature on/off”; use a nested object with **`enabled = bool`** when a capability is opt-in (defer until needed in Phase 2).

```hcl
variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t4g.small"
  nullable    = false
}
```

**AMI build flow** (orchestrated by **`make`** → `images/setup-images.sh`):

```text
make images-infra-plan      # fmt, validate, trivy, terraform plan (no apply)
make images-infra-deploy    # gate 3a — plan + terraform apply (builder VPC/subnet)
make images-config-build    # deploy + packer build → gate 3b (AMI in AWS)
make images-infra-destroy   # tear down builder infra (defer during early dev)
```

---



## Validation ladder — `make check` (the real work)

Define `./scripts/phase2-check.sh` **before** heavy infra work. Run it only via **`make check`** so skip/run flags export correctly.


| Gate         | Check                                    | Proves                          |
| ------------ | ---------------------------------------- | ------------------------------- |
| Devbox       | pinned toolchain versions                | dev environment matches Loop 2  |
| Ansible syntax | `ansible-playbook --syntax-check -i "default," ami.yaml` (from `images/config/ansible/`) | AMI playbook and roles parse |
| Ansible lint | `ansible-lint ami.yaml` (from `images/config/ansible/`) | AMI roles follow ansible-lint rules |
| TF static + plan (2–3) | `make cluster-infra-plan` (or `cluster-infra-validate` when `SKIP_TF_PLAN=1`) | cluster HCL sane; AWS shape coherent |
| AMI apply (3a) | `make images-infra-deploy`      | builder infra applied           |
| AMI artifact (3b) | base AMI in AWS (`describe-images`; or `make images-config-build` when `RUN_PACKER_BUILD=1`) | node image ready                |
| Provision (4) | `make cluster-infra-deploy` (only when `RUN_CLUSTER_APPLY=1`) | EC2 / network / EICE exist      |
| EICE SSH (5) | SSH to node via `aws ec2-instance-connect` / open-tunnel (devbox shell) | private node reachable |
| Bootstrap (6) | `kubeadm-init.service` Result=success, journal `Bootstrap complete`, `kubelet` enabled (polls via EICE) | first-boot finished + reboot-safe |
| Cluster (7)   | `kubectl` on node: 1 node Ready, all pods Running/Ready (polls via EICE) | schedulable cluster |
| Smoke (8)     | nginx deployment `phase2-smoke-nginx` Ready 1/1 with pod IP (EICE kubectl on node) | workload path works |

Skip flags: `make help` lists all `SKIP_*` / `RUN_*` variables.

Skip Ansible syntax only: `make check SKIP_AMI_ANSIBLE_SYNTAX=1`

Skip Ansible lint only: `make check SKIP_AMI_ANSIBLE_LINT=1`

Gate 4 runs `make cluster-infra-deploy` only with `RUN_CLUSTER_APPLY=1`. Skip it with `SKIP_TF_APPLY=1`. Gate 5 (EICE SSH) runs when cluster outputs exist. Skip bootstrap/cluster/smoke (gates 6–8) with `SKIP_ANSIBLE=1` — ladder exits successfully after gate 5:

```bash
make check RUN_CLUSTER_APPLY=1
make check RUN_CLUSTER_APPLY=1 SKIP_ANSIBLE=1
make check SKIP_TF_APPLY=1 SKIP_ANSIBLE=1
make help    # all targets and flags
```

Skip cluster TF during AMI-only iteration: `make check SKIP_CLUSTER_TF=1`


**Done when:** `make check` exits 0.

---



## Agentic loop workflow (Loop 1)

```text
Goal + constraints + repo state
        ↓
Agent edits TF / Packer / Ansible
        ↓
Run make check
        ↓
All gates pass? ──Yes──→ Phase 2 done
        │
        No → feed stderr back → repeat
```

Prompt shape for Cursor:

```text
Goal: functional single-node kubeadm cluster on AWS (ca-central-1).
Constraints: 1 private node (CP + worker), t4g.small, EICE access, kubeadm built-in PKI, Cilium, AMI first-boot bootstrap (cloud-init + systemd), devbox shell, greenfield — inspired by ~/DEV/k8s-homelab, no copy.
Validation: make check must exit 0.
Current failure: <paste stderr>
Fix only what the checks require.
```

---



## Access pattern (EC2 Instance Connect — like k8s-homelab)

Homelab does **not** use a bastion. Private nodes + **EC2 Instance Connect Endpoint**:

```text
Your laptop
     │  aws ec2-instance-connect open-tunnel
     ▼
 EICE (in VPC, private subnet)
     │  SSH
     ▼
 k8s node (private subnet, t4g.small — CP + worker)
```

Example (from homelab):

```bash
ssh -i ~/.ssh/id_rsa_k8s_homelab ubuntu@<instance-id> \
  -o ProxyCommand='aws ec2-instance-connect open-tunnel --instance-id <instance-id>'
```

- **Nodes:** private subnet, no public IP
- **NAT gateway:** outbound internet for pulls (homelab pattern)
- **kubeconfig:** `/etc/kubernetes/admin.conf` on node; fetch via EICE SSH

**k8s-homelab reference:** 2× `t4g.small` (1 CP + 1 worker). This project uses **1×** `t4g.small` (combined node).

---



## k8s-homelab vs this project


|                  | k8s-homelab             | vllm-deployment phase2      |
| ---------------- | ----------------------- | --------------------------- |
| **Bootstrap**    | kubeadm on first boot   | kubeadm on first boot       |
| **Bootstrap how**| cloud-init → systemd → `kubeadm-init.sh` | same (single-node script; no SSM) |
| **PKI**          | kubeadm built-in        | kubeadm built-in            |
| **CNI**          | Cilium                  | Cilium                      |
| **OS / AMI**     | Ubuntu 24.04            | Ubuntu Server 26.04 LTS arm64 |
| **Access**       | EICE                    | EICE                        |
| **Nodes**        | 1 CP + 1 worker         | 1 CP + worker (single node) |
| **Region / SKU** | ca-central-1, t4g.small | ca-central-1, t4g.small     |


KTHW (`kubernetes-the-hard-way-on-aws`) is a **different** project — manual components, custom OpenSSL PKI, bastion, no kubeadm. Not the reference for this phase.

---



## Repo layout

```text
phase2/
├── Makefile                                     # primary entrypoint (make check, make *-infra-*)
├── devbox.json
├── modules/infra/                               # shared TF child modules (no state)
├── cluster/
│   ├── setup-cluster.sh                         # invoked by Makefile only
│   └── infra/
│       ├── main-account/ca-central-1/prod/      # cluster live root
│       └── modules/                             # cluster-specific TF modules
├── images/
│   ├── setup-images.sh                          # invoked by Makefile only
│   ├── infra/main-account/ca-central-1/prod/    # ephemeral live — Packer builder network
│   └── config/
│       ├── packer/
│       └── ansible/                             # ami.yaml + roles (Packer bake + first-boot wiring)
├── configuration/                             # not used for Phase 2 bootstrap (defer / other uses)
└── scripts/
    ├── phase2-check.sh                          # ladder; calls make targets only
    └── cluster.sh                               # thin wrapper → make
```

---



## Checklist (implementation tasks)

- [ ] `Makefile` + validation ladder wired (`make check`; check script uses `make` targets only)
- [ ] Scaffold `modules/infra/` (shared child modules — VPC, etc.)
- [ ] Scaffold `cluster/infra/main-account/ca-central-1/prod/` (cluster live — VPC, NAT, EICE, EC2)
- [ ] Scaffold `images/infra/main-account/ca-central-1/prod/` (ephemeral Packer builder network)
- [ ] Scaffold `images/config/packer/` + `images/config/ansible/` (`ami.yaml` + roles)
- [ ] Pin versions in `group_vars/all.yaml`; template kubeadm config + bootstrap script from vars
- [ ] Packer + Ansible: base AMI (containerd, kubeadm, Cilium CLI) **+ kubeadm-init.sh, systemd unit, cloud-init**
- [ ] Single-node bootstrap in baked script: `kubeadm init`, `cilium install`, remove CP taint, `systemctl enable kubelet`
- [ ] `cluster.sh` thin wrapper → `make` (bootstrap is first boot, not a configure step)
- [ ] Ladder green: node Ready, smoke pod Running (kubectl **on node** via EICE)

---



## Loop 2 decisions

- **Dev environment:** devbox in `phase2/` — terraform **1.15.3**, packer **1.15.3**, ansible **2.21.1**, ansible-lint **25.8.2**, awscli2 **2.34.24**, jq **1.8.2**, trivy **0.72.0**, pre-commit **4.5.1**, git **2.54.0**
- **Region:** ca-central-1 (Canada Central)
- **Instance type:** `t4g.small` (ARM64 Graviton)
- **OS:** Ubuntu Server **26.04 LTS (arm64)** — Packer base AMI (homelab uses 24.04)
- **Topology:** 1 private node (control plane + worker)
- **Access:** EC2 Instance Connect Endpoint (homelab pattern)
- **PKI:** kubeadm built-in
- **CNI:** Cilium **`cilium_version`** from `group_vars` — `cilium install` in first-boot script; cilium-cli **v0.19.7** baked in AMI
- **Kubernetes:** **1.36.3** (pinned in `group_vars`; consumed by kubeadm-config + init script)
- **Bootstrap mechanism:** **AMI first-boot** — cloud-init → `kubeadm-init.service` → shell script (`kubeadm init`, `cilium install`, CP taint removal). **Not** runtime Ansible under `configuration/`. Same model as k8s-homelab.
- **SSM bootstrap coordination:** **not used in Phase 2** — homelab uses SSM for CP/worker join across two nodes; single-node MVP has no join path. Revisit if topology splits CP + workers.
- **kubectl / kubeconfig:** **on the node only** (homelab smoke-test style) — SSH via EICE, `KUBECONFIG=/etc/kubernetes/admin.conf` on the node; laptop kubeconfig deferred to [Phase 3](../phase3/README.md)
- **K8s upgrade path:** **rebuild AMI** at new version → **rolling replace** nodes (workers first, CP last) — not in-place `kubeadm upgrade` playbooks. Phase 2 bootstraps **one** node; expect **multi-node** topology by first real upgrade.
- **Packer build infra:** ephemeral — **`make images-infra-*`** / **`make images-config-build`**; **`make images-infra-destroy`** after first AMI is stable (defer during early dev)
- **Orchestration:** **`Makefile`** entrypoint; `make check` → `phase2-check.sh` → **`make` targets only** (never `setup-*.sh` from check script); setup scripts invoked by Makefile recipes; flags on `make` CLI (`make help`)
- **AMI config layout:** `images/config/packer/` + `images/config/ansible/` (same split as k8s-homelab)
- **Terraform modules:** shared `modules/infra/` — used by `images/infra/main-account/ca-central-1/prod/` and `cluster/infra/main-account/ca-central-1/prod/`; cluster-specific modules under `cluster/infra/modules/`
- **Terraform variables:** **`nullable = false`** on every variable in live roots and child modules (including variables with defaults); see [Variables](#variables) under Terraform layout
- **AWS provider:** `hashicorp/aws` **`~> 6.60.0`** — identical `versions.tf` on every live root and every `modules/infra/*/` child (homelab uses 5.86)

---



## Next

→ [Phase 3](../phase3/README.md)
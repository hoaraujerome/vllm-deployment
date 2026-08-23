# Phase 3 — WireGuard access

**Status:** not started (Loop 2 frozen 2026-08-23)

**Prerequisite:** [Phase 2](../phase2/README.md) — functional K8s cluster; `make check-cluster` exit 0

**Repo:** `~/DEV/vllm-deployment/phase3` — WireGuard provisioning, configuration, `phase3-check.sh`

**Reference architecture (inspirational, not a fork):** `~/DEV/k8s-homelab` — NAT public subnet + EICE break-glass.

---

## Done when

`./scripts/phase3-check.sh` exits 0 — **kubectl from your laptop** reaches the cluster over WireGuard (no EICE tunnel required for routine ops).

**Day-to-day (after Phase 3):** WireGuard on → `kubectl` / `helm` from laptop. Cluster health still via Phase 2: `make check-cluster`.

---



## Mindset — loop engineering

Phase 2 proved the **cluster contract** (EICE → node → kubectl on node). Phase 3 proves the **access contract** — laptop-native admin over VPN so [Phase 4](../phase4/README.md)+ can run Helm and check scripts locally.

[Loop engineering](https://www.deeplearning.ai/the-batch/issue-359) — the agent does not decide when Phase 3 is done. `phase3-check.sh` **does.**

### Three loops


| Loop                        | Cadence           | Who drives it           | Phase 3 role                                                          |
| --------------------------- | ----------------- | ----------------------- | --------------------------------------------------------------------- |
| **1 — Agentic coding**      | seconds → minutes | Cursor + terminal       | WireGuard TF, server/client config, kubeconfig on laptop → run checks |
| **2 — Engineer feedback**   | hours             | You (platform engineer) | Freeze constraints in this README; reject scope creep into Phase 2    |
| **3 — Production feedback** | days              | Metrics + users         | Mostly [Phase 6](../phase6/README.md)                                 |




### Two contracts (Phase 2 vs 3)

```text
Phase 2 contract (DONE — don't break)
  "Private K8s cluster exists and survives reboot"
  Proof:  make check-cluster  (EICE → node → kubectl on node)

Phase 3 contract (NEW)
  "Laptop can admin the same cluster over VPN"
  Proof:  ./scripts/phase3-check.sh  (kubectl from laptop, no EICE)
```

Phase 3 **depends on** Phase 2. It does **not replace** Phase 2 validation — keep EICE as break-glass until WireGuard is stable.

**Rule of thumb:** if it exists to **run the cluster**, Phase 2. If it exists so **your laptop can reach** the cluster, Phase 3.

---



## Goal (Phase 3**don** — start here)

Deploy **WireGuard** so your laptop joins the private VPC and uses `kubectl` / `helm` against the Phase 2 API server directly.

```text
Goal:     laptop → WireGuard → private VPC → kubectl works locally
Replace:  EICE as primary admin access (keep EICE break-glass)
Cluster:  unchanged Phase 2 node (ca-central-1, private subnet)
Endpoint: dedicated t4g.nano in nat-gateway subnet (Option A)
Deliver:  kubeconfig on laptop (API server private IP reachable over VPN)
Scope:    VPN only — no vLLM, no ingress
```

---



## Why a separate phase


|               | Phase 2 (EICE)                | Phase 3 (WireGuard)        |
| ------------- | ----------------------------- | -------------------------- |
| **Ops style** | SSH to node, kubectl on node  | kubectl / helm from laptop |
| **Session**   | new EICE tunnel each time     | persistent VPN             |
| **Phase 4**   | awkward for local Helm ladder | natural                    |


---



## Constraints (Loop 2 — frozen for Phase 3)

- **Greenfield access layer:** new code under `phase3/` — do not reopen Phase 2 cluster factory (AMI, bootstrap, Cilium pins)
- **VPN:** **WireGuard** on a **dedicated** `t4g.nano` **EC2** — not co-located on the K8s node
- **Subnet (Option A):** reuse Phase 2 `nat-gateway` subnet (`10.60.2.0/24`, IGW route) — NAT egress + WireGuard admin ingress share the subnet; no new subnet for MVP
- **Elastic IP:** attach explicitly — Phase 2 subnets use `map_public_ip_on_launch = false`
- **Tunnel:** **split** — route only VPC CIDR (`10.60.0.0/16`) over VPN; do not full-tunnel all laptop traffic
- **EICE:** **keep indefinitely** as break-glass — do not remove from Phase 2 TF in Phase 3
- **Region / account:** same as Phase 2 — **ca-central-1**, sandbox account
- **Terraform — Phase 2 touch:** **outputs only** — `vpc_id`, `nat_gateway_subnet_id`, `k8s_node_security_group_id`, `k8s_node_private_ip` (small additive MR to Phase 2 cluster live root)
- **Terraform — Phase 3 owns:** WireGuard EC2, EIP, WireGuard SG, K8s SG ingress rule (TCP 6443 from WireGuard SG) via `terraform_remote_state` (or copied outputs for v1)
- **Terraform — variables:** `nullable = false` on every `variable` (same rule as Phase 2)
- **Terraform — AWS provider:** `hashicorp/aws` ****`~> 6.60.0` — match Phase 2 pins
- **Configuration:** WireGuard server bootstrap in `phase3/configuration/` (cloud-init or Ansible) — **not** in Phase 2 Packer AMI
- **Secrets:** WireGuard keys and client configs **gitignored** — never commit private keys
- **Kubeconfig:** `~/.kube/vllm-phase2.conf` on laptop; `server:` = node private IP (`https://<ip>:6443`); fetch `admin.conf` via EICE once (break-glass path OK)
- **Orchestration:** `phase3-check.sh` is the done-when entrypoint; optional `phase3/Makefile` for `check`, `fetch-kubeconfig`, etc.
- **No vLLM / no ingress** in Phase 3 — access layer only

Reject and restart Loop 1 when the agent proposes shortcuts that violate these (e.g. WireGuard on K8s node, remove EICE, bake WireGuard into Packer AMI, move laptop kubectl gates into `phase2-check.sh`, change K8s AMI/bootstrap, full-tunnel by default, dedicated public subnet without Loop 2 approval).

### Option A vs dedicated public subnet (deferred)

Option B (separate `wireguard` subnet) improves topology clarity but **costs the same** — subnets and route tables are free. **Loop 2 decision:** Option A for Phase 3 MVP. Revisit Option B only if subnet-level NACL separation becomes a requirement.

---



## Phase 2 vs Phase 3 ownership


| Concern                           | Phase 2      | Phase 3                                  |
| --------------------------------- | ------------ | ---------------------------------------- |
| VPC, subnets, NAT, IGW            | owns         | reads / references                       |
| K8s node, EICE, kubeadm bootstrap | owns         | untouched                                |
| `make check-cluster`              | owns         | run for regression after Phase 3 changes |
| WireGuard EC2 + EIP               | —            | owns                                     |
| WireGuard server + client config  | —            | owns                                     |
| SG: UDP 51820 → WireGuard         | —            | owns                                     |
| SG: TCP 6443 → K8s from WireGuard | shared touch | owns rule; needs Phase 2 SG id           |
| Laptop kubeconfig                 | —            | owns                                     |
| `phase3-check.sh`                 | —            | owns                                     |


**Do not in Phase 3:** change K8s AMI, bootstrap, Cilium pins; remove EICE; move laptop kubectl validation into `phase2-check.sh`; bundle WireGuard into Packer AMI.

---



## Access pattern (WireGuard — Option A)

Phase 2 uses EICE for break-glass SSH. Phase 3 adds WireGuard for routine laptop admin:

```text
Laptop (WireGuard client, e.g. 10.8.0.2)
     │  UDP 51820 → WireGuard EIP
     ▼
WireGuard EC2 (nat-gateway subnet, 10.60.2.x)
     │  VPC routing (10.60.0.0/16)
     ▼
K8s node (k8s-cluster subnet, 10.60.1.x — no public IP)
     └── API server :6443
```



### Subnets (Phase 2 VPC — unchanged)


| Subnet        | CIDR           | Route | Role                            |
| ------------- | -------------- | ----- | ------------------------------- |
| `k8s-cluster` | `10.60.1.0/24` | → NAT | Private — K8s node, EICE        |
| `nat-gateway` | `10.60.2.0/24` | → IGW | Public-facing — NAT + WireGuard |


NAT stays for private subnet outbound (image pulls, etc.). WireGuard is routing + UDP ingress — not a replacement for NAT.

### Security groups (sketch)


| SG        | Rules                                                                                       |
| --------- | ------------------------------------------------------------------------------------------- |
| WireGuard | Inbound UDP 51820 from home IP; outbound to VPC CIDR                                        |
| K8s node  | Inbound TCP 6443 from WireGuard SG (Phase 3 adds via `aws_vpc_security_group_ingress_rule`) |




### Break-glass (Phase 2 — keep)

```text
Your laptop
     │  aws ec2-instance-connect open-tunnel
     ▼
 EICE (private subnet)
     │  SSH
     ▼
 k8s node
```

`make cluster-ssh` from `phase2/` when VPN is down.

---



## Terraform layout

Phase 3 provisioning reads Phase 2 cluster state; Phase 2 cluster live root gains outputs only.


| Purpose                          | Path                                                   | State                                         |
| -------------------------------- | ------------------------------------------------------ | --------------------------------------------- |
| Phase 2 cluster (frozen factory) | `phase2/cluster/infra/main-account/ca-central-1/prod/` | persistent — **outputs extended for Phase 3** |
| Phase 3 WireGuard live           | `phase3/provisioning/terraform/`                       | persistent while VPN exists                   |
| WireGuard bootstrap              | `phase3/configuration/`                                | n/a                                           |


**Split:**

1. **Phase 2** — add outputs: `vpc_id`, `nat_gateway_subnet_id`, `k8s_node_security_group_id`, `k8s_node_private_ip`.
2. **Phase 3** — WireGuard EC2 + EIP + SGs via `terraform_remote_state`.
3. **K8s SG ingress** — Phase 3 TF adds rule; Phase 2 remains source of truth for the node SG resource.

---



## Repo layout

```text
phase2/                          # FROZEN — cluster factory (outputs MR only)
├── cluster/infra/...            # additive outputs for Phase 3
├── Makefile                     # check-cluster, cluster-ssh (break-glass)
└── scripts/phase2-check.sh

phase3/                          # access layer
├── provisioning/
│   └── terraform/               # WireGuard EC2, EIP, SGs; remote state → Phase 2
├── configuration/               # wg0, cloud-init, client profile (secrets gitignored)
├── scripts/
│   └── phase3-check.sh          # done-when ladder
└── Makefile                     # optional: check, fetch-kubeconfig
```

---



## Validation ladder — `phase3-check.sh`

Define gates **before** Terraform sprawl. Run from laptop (WireGuard connected):


| Gate          | Check                                                   | Proves                        |
| ------------- | ------------------------------------------------------- | ----------------------------- |
| 1 — VPN       | WireGuard interface up (`wg show`)                      | tunnel works                  |
| 2 — Cluster   | `kubectl get nodes` **from laptop**                     | kubeconfig over VPN           |
| 3 — EICE-free | script does not call `ec2-instance-connect open-tunnel` | EICE replaced for routine ops |


**Done when:** `./scripts/phase3-check.sh` exits 0.

**Regression (after Phase 3 changes):** `cd ../phase2 && make check-cluster` — Phase 2 break-glass still works.

Usage:

```bash
KUBECONFIG=~/.kube/vllm-phase2.conf ./scripts/phase3-check.sh
```

---



## Work order (Loop 1 — implementation sequence)

```text
0. Baseline
   └── phase2: make check-cluster     # must be green before you start

1. Loop 2 — constraints frozen (this README)

2. Phase 2 outputs (tiny additive MR)
   └── vpc_id, subnet ids, k8s SG id, node private IP

3. Phase 3 provisioning (Terraform)
   ├── WireGuard EC2 in nat-gateway subnet + EIP
   ├── WireGuard SG (UDP 51820 from home IP)
   └── K8s SG ingress: 6443 from WireGuard SG

4. Phase 3 configuration (server bootstrap)
   ├── cloud-init or Ansible: WireGuard, IP forwarding
   ├── server + laptop client keys
   └── PostUp routes → 10.60.1.0/24

5. Laptop client
   ├── WireGuard app + client config
   └── wg show / ping node private IP

6. Kubeconfig
   ├── Fetch admin.conf via EICE (one-time / break-glass OK)
   ├── ~/.kube/vllm-phase2.conf
   └── server: https://<node-private-ip>:6443

7. phase3-check.sh — implement gates 1–3

8. Regression
   └── make check-cluster still green
```

---



## Agentic loop workflow (Loop 1)

```text
Phase 2 cluster running (make check-cluster green)
        ↓
Agent deploys WireGuard + kubeconfig on laptop
        ↓
Run phase3-check.sh from laptop
        ↓
All gates pass? ──Yes──→ Phase 3 done
        │
        No → feed stderr back → repeat
```

Prompt shape for Cursor:

```text
Goal: WireGuard VPN so laptop kubectl reaches Phase 2 private cluster.
Constraints: t4g.nano in nat-gateway subnet; split tunnel; keep EICE; phase3/README.md; minimal diff.
Done when: ./phase3/scripts/phase3-check.sh exits 0 from laptop.
Current failure: <paste stderr>
Fix only what the checks require.
```

---



## Daily navigation (after Phase 3)


| Situation      | Command                                                 |
| -------------- | ------------------------------------------------------- |
| Normal ops     | WireGuard on → `kubectl` / `helm` from laptop           |
| Cluster health | `cd phase2 && make check-cluster` (after infra changes) |
| VPN broken     | `cd phase2 && make cluster-ssh` (EICE break-glass)      |
| Phase 4 vLLM   | `phase4-check.sh` from laptop over VPN                  |


---



## Checklist

- [x] **Loop 2:** WireGuard on dedicated `t4g.nano` (not on K8s node)
- [x] **Loop 2:** Option A — `nat-gateway` subnet
- [x] **Loop 2:** split tunnel (VPC CIDR only)
- [x] **Loop 2:** keep EICE break-glass
- [x] **Loop 2:** Phase 3 owns TF; Phase 2 outputs only
- [ ] Phase 2 cluster outputs for Phase 3 remote state
- [ ] WireGuard EC2 + EIP + SGs (Phase 3 TF)
- [ ] K8s SG ingress: 6443 from WireGuard SG
- [ ] WireGuard server bootstrap (`configuration/`)
- [ ] Laptop client config (gitignored)
- [ ] Kubeconfig on laptop (`~/.kube/vllm-phase2.conf`)
- [ ] `phase3-check.sh` gates 1–3 green
- [ ] Regression: `make check-cluster` still green
- [ ] Document break-glass EICE path in daily navigation (above)

---



## Loop 2 decisions

- **VPN:** WireGuard on dedicated `t4g.nano` EC2 (ARM64 Graviton — match Phase 2 architecture family)
- **Subnet:** **Option A** — reuse Phase 2 `nat-gateway` subnet (`10.60.2.0/24`); no new subnet for MVP
- **Tunnel:** **split** — route `10.60.0.0/16` over VPN only
- **EICE:** **keep indefinitely** — primary admin path moves to WireGuard; EICE remains break-glass
- **Terraform:** Phase 3 `provisioning/terraform/` owns WireGuard; Phase 2 cluster live root adds **outputs only**
- **K8s SG rule:** Phase 3 adds `aws_vpc_security_group_ingress_rule` referencing Phase 2 node SG id
- **Kubeconfig:** laptop file `~/.kube/vllm-phase2.conf`; server URL = node private IP; one-time fetch via EICE OK
- **Validation:** `phase3-check.sh` from laptop; Phase 2 `make check-cluster` for regression
- **Scope:** access layer only — no vLLM, no ingress ([Phase 4](../phase4/README.md) next)

---



## Previous / Next

← [Phase 2](../phase2/README.md)

→ [Phase 4](../phase4/README.md) — vLLM CPU; Helm from laptop over WireGuard
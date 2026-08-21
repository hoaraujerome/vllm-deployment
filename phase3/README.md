# Phase 3 — WireGuard access


**Status:** not started

**Prerequisite:** [Phase 2](../phase2/README.md) (functional K8s cluster; Phase 2 ops via EICE + kubectl on node)

**Repo:** `~/DEV/vllm-deployment/phase3` — WireGuard config, `phase3-check.sh`

---

## Done when

`./scripts/phase3-check.sh` exits 0 — **kubectl from your laptop** reaches the cluster over WireGuard (no EICE tunnel required for routine ops).

---

## Mindset — loop engineering

Phase 2 proved the **cluster contract** with homelab-simple ops (SSH via EICE, kubectl on the node). Phase 3 proves the **access contract** — replace EICE as the primary admin path with WireGuard so Phase 4+ can run Helm and check scripts locally.

### Three loops

| Loop | Cadence | Who drives it | Phase 3 role |
| ---- | ------- | ------------- | -------------- |
| **1 — Agentic coding** | seconds → minutes | Cursor + terminal | WireGuard server/client, SG rules, kubeconfig on laptop |
| **2 — Engineer feedback** | hours | You | Endpoint placement, split vs full tunnel, keep EICE as break-glass? |
| **3 — Production feedback** | days | Metrics + users | [Phase 6](../phase6/README.md) |

---

## Goal (start here — refine in Loop 2)

Deploy **WireGuard** so your laptop joins the private VPC network and can use `kubectl` / `helm` against the Phase 2 API server directly.

```text
Goal:     laptop → WireGuard → private VPC → kubectl works locally
Replace:  EICE as primary admin access (optional: keep EICE break-glass)
Cluster:  unchanged Phase 2 node (ca-central-1, private subnet)
Deliver:  kubeconfig on laptop (API server private IP reachable over VPN)
Scope:    VPN only — no vLLM, no ingress
```

---

## Why a separate phase

| | Phase 2 (EICE) | Phase 3 (WireGuard) |
| --- | --- | --- |
| **Ops style** | SSH to node, kubectl on node | kubectl / helm from laptop |
| **Session** | new EICE tunnel each time | persistent VPN |
| **Phase 4** | awkward for local Helm ladder | natural |

---

## Validation ladder — `phase3-check.sh`

| Gate | Check | Proves |
| ---- | ----- | ------ |
| VPN | WireGuard interface up on laptop | tunnel works |
| Cluster | `kubectl get nodes` **from laptop** | kubeconfig over VPN |
| Routine | ops without `ec2-instance-connect open-tunnel` | EICE replaced |

**Done when:** `./phase3/scripts/phase3-check.sh` exits 0.

---

## Agentic loop workflow (Loop 1)

```text
Phase 2 cluster running (EICE + on-node kubectl still works)
        ↓
Agent deploys WireGuard + kubeconfig on laptop
        ↓
Run phase3-check.sh from laptop
        ↓
All gates pass? ──Yes──→ Phase 3 done
```

Prompt shape for Cursor:

```text
Goal: WireGuard VPN so laptop kubectl reaches Phase 2 private cluster.
Constraints: replace EICE for routine ops; kubeconfig on laptop; greenfield in phase3/.
Validation: ./phase3/scripts/phase3-check.sh must exit 0 from laptop.
Current failure: <paste stderr>
Fix only what the checks require.
```

---

## Repo layout

```text
phase3/
├── provisioning/           # optional: WG endpoint EC2, SG rules
├── configuration/          # wg0, client profiles, Ansible
└── scripts/
    └── phase3-check.sh
```

---

## Checklist

- [ ] **Loop 2:** WireGuard server — dedicated EC2 vs on K8s node
- [ ] **Loop 2:** split tunnel vs full tunnel on laptop
- [ ] WireGuard server + client configs
- [ ] SG / routing: laptop peer → VPC private CIDR
- [ ] Copy/adapt admin.conf to laptop; fix server URL if needed
- [ ] `phase3-check.sh`: kubectl from laptop over VPN
- [ ] Document break-glass EICE path (optional)

---

## Open questions (Phase 3)

- WireGuard endpoint placement (tiny EC2 vs co-locate on K8s node)
- Remove EICE from TF after WireGuard stable, or keep both
- Terraform vs manual for first pass

---

## Previous / Next

← [Phase 2](../phase2/README.md)

→ [Phase 4](../phase4/README.md)

# Phase 3 — WireGuard access

Replace **EC2 Instance Connect (EICE)** with a **WireGuard VPN** so your laptop reaches the private VPC — enabling local `kubectl`, `helm`, and Phase 4 check scripts without SSH-ing into the node for every command.

**Status:** not started

**Prerequisite:** [Phase 2](../phase2/README.md) complete (functional K8s cluster; Phase 2 ops use EICE + kubectl on node)

## Done when

`./scripts/phase3-check.sh` exits 0:

| Gate | Check | Proves |
| ---- | ----- | ------ |
| VPN up | WireGuard tunnel active on laptop | laptop on VPC network |
| Reach API | `kubectl get nodes` from laptop | kubeconfig works over VPN |
| No EICE required | routine ops without `ec2-instance-connect open-tunnel` | EICE replaced for day-to-day |

## Why this phase

| | Phase 2 (EICE) | Phase 3 (WireGuard) |
| --- | --- | --- |
| **Cluster ops** | SSH to node, kubectl on node | kubectl / helm from laptop |
| **Access** | `aws ec2-instance-connect open-tunnel` per session | persistent VPN |
| **Phase 4 fit** | awkward for Helm check scripts | natural |

Phase 2 intentionally keeps ops homelab-simple (kubectl on node). Phase 3 unlocks laptop-native tooling for vLLM deploy and beyond.

## Layout (planned)

```text
phase3/
├── README.md
├── provisioning/           # optional: WireGuard endpoint (EC2 or existing node)
├── configuration/          # wg0 config, Ansible, or cloud-init
└── scripts/
    └── phase3-check.sh
```

## Starting spec (Loop 2 — refine as you learn)

```text
Goal:     laptop reaches private VPC via WireGuard; kubectl from laptop works
Replace:  EICE as primary admin access (may keep EICE as break-glass)
Cluster:  same Phase 2 node (ca-central-1, private subnet)
Deliver:  kubeconfig on laptop (server = private API IP, reachable over VPN)
Scope:    VPN only — no vLLM, no ingress
```

## Open questions

- WireGuard server: dedicated tiny EC2 vs run on the K8s node
- Terraform for WG endpoint + SG rules vs manual first pass
- Split tunnel vs full tunnel on laptop
- Remove EICE from TF once WireGuard is stable, or keep both

## Next

→ [Phase 4](../phase4/README.md) — deploy vLLM CPU (Helm from laptop)

# Phase 4 — Kubernetes deployment


**Status:** not started

**Prerequisite:** [Phase 3](../phase3/README.md) (kubectl / Helm from laptop over VPN)

**Repo:** `~/DEV/vllm-deployment/phase4` — Helm chart, `phase4-check.sh`

---

## Done when

Validation ladder passes on the cluster from **your laptop** (via WireGuard); vLLM pod is running and reachable inside the cluster via ClusterIP. Real inference works on **CPU** — no NVIDIA/CUDA yet ([Phase 5](../phase5/README.md)).

---

## Mindset — loop engineering

Phase 1 proved the **inference contract** locally. Phase 2 proved the **cluster contract**. Phase 3 proved **laptop access**. Phase 4 proves the **workload deployment contract** — Helm, Service, in-cluster API — without GPU complexity.

### Three loops

| Loop | Cadence | Who drives it | Phase 4 role |
| ---- | ------- | ------------- | -------------- |
| **1 — Agentic coding** | seconds → minutes | Cursor + terminal | Edit chart → run checks from laptop |
| **2 — Engineer feedback** | hours | You | Node upsize for RAM, reject bad shortcuts |
| **3 — Production feedback** | days | Metrics + users | [Phase 6](../phase6/README.md) |

---

## Goal (start here — refine in Loop 2)

Deploy vLLM (CPU build) on the cluster, serving a tiny Hugging Face model, reachable inside the cluster via ClusterIP (no ingress yet — [Phase 6](../phase6/README.md)).

```text
Goal:     vLLM on cluster, in-cluster inference API works (CPU)
Access:   kubectl / helm from laptop (Phase 3 WireGuard)
Model:    Qwen/Qwen2.5-0.5B-Instruct
Image:    official vLLM CPU image (arm64 on Graviton)
Weights:  HF Hub pull at startup
Packaging: Helm chart
Scope:    1 replica, ClusterIP, no GPU
```

**Optional Loop 1:** iterate chart on **kind** locally. Phase 4 is not done until the ladder passes on the real cluster via WireGuard.

---

## Constraints (Loop 2)

- **Access:** laptop kubeconfig over WireGuard (Phase 3) — not on-node kubectl
- **Node sizing:** upsize from Phase 2 `t4g.small` before vLLM (first Loop 2 task)
- **Runtime:** vLLM CPU — not Metal, not CUDA
- **No GPU** in Phase 4

---

## Validation ladder — `phase4-check.sh`

| Gate | Check | Proves |
| ---- | ----- | ------ |
| Static | `helm lint`, manifest lint | valid chart |
| Artifact | vLLM CPU image pulls | runtime reachable |
| Deploy | helm install, pod Ready | scheduler + startup |
| Functional | in-cluster `/v1/chat/completions` | CPU inference |
| Resource | model loaded, no OOM | RAM fit |

**Done when:** `./phase4/scripts/phase4-check.sh` exits 0 from laptop.

---

## Checklist

- [ ] Upsize K8s node from `t4g.small` for vLLM RAM
- [ ] Helm chart / Deployment + Service (ClusterIP)
- [ ] Write `phase4-check.sh`
- [ ] Ladder green from laptop over WireGuard

---

## Open questions (Phase 4)

- Target instance type after upsize
- arm64 vLLM CPU image on Graviton
- Helm values profiles (CPU now, GPU in Phase 5)

---

## Previous / Next

← [Phase 3](../phase3/README.md)

→ [Phase 5](../phase5/README.md)

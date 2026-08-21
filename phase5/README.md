# Phase 5 — NVIDIA CUDA GPU


**Status:** not started

**Prerequisite:** [Phase 4](../phase4/README.md) (vLLM CPU in-cluster works)

**Repo:** `~/DEV/vllm-deployment/phase4` (extend chart) + Phase 2 cluster (add GPU capacity)

---

## Done when

Validation ladder passes with **GPU scheduling**; vLLM pod runs with `nvidia.com/gpu`, loads a CUDA-compatible model, and in-cluster `/v1/chat/completions` works without OOM.

---

## Mindset

Phase 4 proved **workload deploy on CPU**. Phase 5 adds the **GPU inference contract** — NVIDIA/CUDA on the same cluster.

### Three loops

| Loop | Cadence | Who drives it | Phase 5 role |
| ---- | ------- | ------------- | -------------- |
| **1 — Agentic coding** | seconds → minutes | Cursor + terminal | GPU nodes, CUDA image, device plugin |
| **2 — Engineer feedback** | hours | You | GPU SKU, VRAM, weight strategy |
| **3 — Production feedback** | days | Metrics + users | [Phase 6](../phase6/README.md) |

---

## Goal

Extend cluster with GPU-capable nodes and Phase 4 Helm chart with CUDA. ClusterIP only — no ingress ([Phase 6](../phase6/README.md)).

```text
Goal:     vLLM CUDA on GPU nodes, in-cluster inference works
GPU:      nvidia.com/gpu: 1
Image:    official vLLM CUDA image
```

---

## Validation ladder

Extend Phase 4 checks with GPU gates (`phase5-check.sh` TBD).

**Done when:** check script exits 0 on GPU-backed cluster.

---

## Previous / Next

← [Phase 4](../phase4/README.md)

→ [Phase 6](../phase6/README.md)

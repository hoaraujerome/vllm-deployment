# Phase 4 — vLLM on Kubernetes

Deploy vLLM (CPU build) on the cluster with CPU-only nodes. Proves the **workload deployment contract**: Helm chart, ClusterIP Service, in-cluster `/v1/chat/completions` — no NVIDIA/CUDA yet.

**Status:** not started

**Prerequisite:** [Phase 3](../phase3/README.md) complete (WireGuard — `kubectl` / Helm from laptop)

## Done when

`./scripts/phase4-check.sh` exits 0 against the cluster from your laptop (via WireGuard):

| Gate | Check |
| ---- | ----- |
| Static | `helm lint`, manifest lint |
| Artifact | vLLM CPU image pulls on cluster |
| Deploy | pod Ready |
| Functional | in-cluster `/v1/chat/completions` |
| Resource | model loaded, no OOM |

Optional: iterate the chart on **kind** locally (Loop 1). Phase 4 is not done until the ladder passes on the real cluster via WireGuard kubeconfig.

## Layout

```text
phase4/
├── README.md
├── helm/vllm/
├── kind/                   # optional local chart iteration
└── scripts/
    └── phase4-check.sh
```

## Starting spec (Loop 2)

```text
Cluster:  Phase 2 kubeadm cluster (kubectl via Phase 3 WireGuard)
Node:     upsize from t4g.small before vLLM deploy
Model:    Qwen/Qwen2.5-0.5B-Instruct
Image:    official vLLM CPU image (arm64 if on Graviton)
Weights:  Hugging Face Hub pull at startup
Scope:    1 replica, ClusterIP, no GPU
```

## Loop 2 note — instance sizing

Phase 2 uses **`t4g.small` (2 GiB)** — enough for kubeadm + smoke pod, not for vLLM. **First Phase 4 task:** upsize the K8s node before running the inference ladder.

## Next

→ Phase 5 — add GPU + NVIDIA/CUDA (see project README)

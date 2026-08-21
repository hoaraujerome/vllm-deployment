# vLLM deployment

Hands-on project to run [vLLM](https://docs.vllm.ai/) locally, then deploy it on Kubernetes — including bootstrapping the cluster from greenfield code.

**This repo is the source of truth** for phase constraints, Loop 2 decisions, validation ladders, and check scripts. Obsidian (`secondbrain/coding/1-projects/vllm-deployment/Deploy vLLM Locally and on K8s.md`) is the project index only.

## Project phases

| Phase | Goal | Status | Doc |
| ----- | ---- | ------ | --- |
| **1 — Local** | vLLM-Metal on Apple Silicon | Done | [phase1/README.md](phase1/README.md) |
| **2 — Cluster** | kubeadm cluster on AWS (EICE, kubectl on node) | In progress | [phase2/README.md](phase2/README.md) |
| **3 — WireGuard** | VPN access — laptop kubectl replaces EICE | Planned | [phase3/README.md](phase3/README.md) |
| **4 — vLLM deploy** | vLLM CPU; in-cluster API works | Planned | [phase4/README.md](phase4/README.md) |
| **5 — GPU** | NVIDIA/CUDA | Planned | [phase5/README.md](phase5/README.md) |
| **6 — Operate** | Expose externally; metrics | Planned | [phase6/README.md](phase6/README.md) |

```text
Phase 1        Phase 2           Phase 3          Phase 4         Phase 5        Phase 6
(local)        (cluster)         (WireGuard)      (vLLM)          (GPU)          (operate)
```

Reference architecture: `~/DEV/k8s-homelab` — greenfield code in this repo.

## Repository layout

```text
vllm-deployment/
├── README.md
├── phase1/          # local vLLM-Metal
├── phase2/          # cluster factory (TF, Packer, kubeadm)
├── phase3/          # WireGuard access
├── phase4/          # vLLM workload (Helm, phase4-check.sh)
├── phase5/          # GPU extension (planning)
└── phase6/          # expose & observe (planning)
```

## Design notes

- **Phase 2 ops:** kubectl on node only (homelab smoke-test style).
- **Phase 3:** WireGuard unlocks laptop-native Helm/kubectl for Phase 4+.
- **Validation-driven:** each phase completes when its check script passes.
